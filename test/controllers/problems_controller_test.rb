require "test_helper"
require "tmpdir"

class ProblemsImportExportControllerTest < ActionDispatch::IntegrationTest
  EXAMPLES = Rails.root.join("test", "problem_examples")

  setup do
    sign_in_as("admin", "admin")
    # a real problem to import testcases into
    pi = ProblemImporter.new
    pi.import_dataset_from_dir(EXAMPLES.join("fibo_minimal").to_s, "pct_fibo",
                               do_solutions: false)
    @problem = pi.problem
  end

  test "import_testcases replace with invalid dataset id errors instead of creating a dataset" do
    assert_no_difference "Dataset.count" do
      post import_testcases_problem_path(@problem), params: {
        import: { file: fixture_zip, target: "replace", dataset: 0,
                  input_pattern: "*.in", sol_pattern: "*.sol" }
      }, as: :turbo_stream
    end
    assert_response :success
    assert_match(/not found/i, response.body)
  end

  test "import_testcases does not touch the problem attachment" do
    @problem.attachment.attach(io: StringIO.new("keep me"), filename: "keep.txt")
    @problem.save
    post import_testcases_problem_path(@problem), params: {
      import: { file: fixture_zip, target: "new",
                input_pattern: "*.in", sol_pattern: "*.sol" }
    }, as: :turbo_stream
    @problem.reload
    assert_equal "keep me", @problem.attachment.download
  end

  test "group editor cannot overwrite an existing problem they cannot edit" do
    # @problem ('pct_fibo') exists and belongs to no group mary can edit
    group = Group.create!(name: "marys_group", enabled: true)
    GroupUser.create!(group: group, user: users(:mary), role: :editor)
    sign_in_as("mary", "mary")

    assert_no_difference -> { @problem.live_dataset.testcases.count } do
      post do_import_problems_path, params: {
        problem: { name: @problem.name, full_name: "Takeover",
                   file: fixture_zip, groups: group.id,
                   input_pattern: "*.in", sol_pattern: "*.sol",
                   time_limit: 1, memory_limit: 64 }
      }
    end
    assert_match(/already exists/i, response.body)
    assert_not_equal "Takeover", @problem.reload.full_name
  end

  test "admin can still re-import over an existing problem" do
    post do_import_problems_path, params: {
      problem: { name: @problem.name, full_name: "Updated by admin",
                 file: fixture_zip, groups: "",
                 input_pattern: "*.in", sol_pattern: "*.sol",
                 time_limit: 1, memory_limit: 64 }
    }
    assert_equal "Updated by admin", @problem.reload.full_name
  end

  test "non-admin editor of the existing problem can re-import to update it" do
    set_grader_config("system.use_problem_group", "true")
    group = Group.create!(name: "marys_edit_group", enabled: true)
    group.problems << @problem
    GroupUser.create!(group: group, user: users(:mary), role: :editor)
    sign_in_as("mary", "mary")

    # setup sanity: mary can actually edit the existing problem now
    assert users(:mary).problems_for_action(:edit).where(id: @problem.id).exists?,
           "test setup: mary must be able to edit the existing problem"

    post do_import_problems_path, params: {
      problem: { name: @problem.name, full_name: "Mary Updated",
                 file: fixture_zip, groups: group.id,
                 input_pattern: "*.in", sol_pattern: "*.sol",
                 time_limit: 1, memory_limit: 64 }
    }, as: :turbo_stream

    assert_equal "Mary Updated", @problem.reload.full_name
  end

  test "download_archive on a problem without live dataset redirects with alert" do
    bare = Problem.create!(name: "no_live_ds", full_name: "Bare")
    get download_archive_problem_path(bare)
    assert_redirected_to problems_path
    assert_match(/no live dataset/i, flash[:alert])
  end

  private

  # A zip whose root has 9.in, 9.sol, and attachment/sneaky.txt — the
  # attachment/ dir lets the second test prove the testcases-only flow
  # leaves the problem attachment alone.
  def fixture_zip
    @fixture_zip ||= begin
      dir = Dir.mktmpdir
      File.write(File.join(dir, "9.in"), "9\n")
      File.write(File.join(dir, "9.sol"), "34\n")
      att = File.join(dir, "attachment")
      FileUtils.mkdir_p(att)
      File.write(File.join(att, "sneaky.txt"), "should not import\n")
      system("zip", "-q", "-r", "tc.zip", ".", "-x", "tc.zip", chdir: dir) or raise "zip failed"
      Rack::Test::UploadedFile.new(File.join(dir, "tc.zip"), "application/zip")
    end
  end
end
