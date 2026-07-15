require "test_helper"
require "tmpdir"

class ProblemsControllerTest < ActionDispatch::IntegrationTest
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
