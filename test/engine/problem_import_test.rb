require "test_helper"
require "tmpdir"

class ProblemImportTest < ActiveSupport::TestCase
  EXAMPLES = Rails.root.join("test", "problem_examples")

  # Import a problem-example directory (no zip involved) and return the importer.
  def import_example(dir, name, **opts)
    pi = ProblemImporter.new
    pi.import_dataset_from_dir(dir.to_s, name, **opts)
    pi
  end

  test "fibo example imports with fields from config.yml" do
    pi = import_example(EXAMPLES.join("fibo"), "fibo_test", do_solutions: false)
    problem = pi.problem
    ds = pi.dataset

    assert_equal "fibo_test", problem.name
    assert_equal "Fibonacci Number", problem.full_name   # from config.yml
    assert_equal "batch", problem.task_type
    assert_equal "self_contained", problem.compilation_type
    assert_equal %w[Book DP], problem.tags.pluck(:name).sort
    assert problem.statement.attached?, "statement.pdf should attach"

    assert_equal 1.0, ds.time_limit.to_f
    assert_equal 512, ds.memory_limit
    assert_equal "sum", ds.score_type
    assert_equal "default", ds.evaluation_type
    assert_equal 8, ds.testcases.count
    # config.yml assigns each testcase its own group with weight 10
    assert_equal (1..8).to_a, ds.testcases.order(:num).pluck(:group)
    assert_equal [10] * 8, ds.testcases.order(:num).pluck(:weight)
    tc1 = ds.testcases.find_by(code_name: "1")
    # content identical to the fixture file (importer only strips \r)
    assert_equal File.read(EXAMPLES.join("fibo", "testcases", "1.in")),
                 tc1.inp_file.download
  end

  test "code_name_regex extracts codename from wildcard match" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "case_1.in"), "in1\n")
      File.write(File.join(dir, "case_1.sol"), "out1\n")
      pi = import_example(dir, "cnr_test", do_solutions: false,
                          code_name_regex: /_(\d+)\z/)
      assert_equal ["1"], pi.dataset.testcases.pluck(:code_name),
                   "code_name_regex should reduce 'case_1' to '1'"
    end
  end

  test "model solutions import with correct filename, model tag, and user" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "1.in"), "1\n")
      File.write(File.join(dir, "1.sol"), "1\n")
      sol_dir = File.join(dir, "model_solutions")
      FileUtils.mkdir_p(sol_dir)
      File.write(File.join(sol_dir, "cpp_fibo.cpp"), "int main(){}\n")

      pi = import_example(dir, "sol_test", user: users(:admin))
      subs = pi.problem.submissions
      assert_equal 1, subs.count, "model solution should create one submission"
      sub = subs.first
      assert_equal "fibo.cpp", sub.source_filename
      assert_equal "cpp", sub.language.name
      assert sub.tag_model?, "imported solution must be tagged :model"
      assert_equal users(:admin), sub.user
    end
  end

  test "blank full_name falls back to problem name" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "1.in"), "1\n")
      File.write(File.join(dir, "1.sol"), "1\n")
      pi = import_example(dir, "fn_test", full_name: "", do_solutions: false)
      assert_equal "fn_test", pi.problem.full_name
    end
  end

  test "legacy package with .md but no markdown key defaults markdown to true" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "1.in"), "1\n")
      File.write(File.join(dir, "1.sol"), "1\n")
      File.write(File.join(dir, "desc.md"), "# Legacy\n")
      pi = import_example(dir, "md_legacy", do_solutions: false)
      assert_equal "# Legacy\n", pi.problem.description
      assert pi.problem.markdown, "markdown should default true for legacy .md packages"
    end
  end

  test "explicit markdown false in config.yml is honored" do
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "1.in"), "1\n")
      File.write(File.join(dir, "1.sol"), "1\n")
      File.write(File.join(dir, "desc.md"), "plain text\n")
      File.write(File.join(dir, "config.yml"), "---\nmarkdown: false\n")
      pi = import_example(dir, "md_false", do_solutions: false)
      assert_equal false, pi.problem.markdown
    end
  end

  test "group_min with mixed weights inside a group logs a warning" do
    Dir.mktmpdir do |dir|
      %w[1-1 1-2].each do |cn|
        File.write(File.join(dir, "#{cn}.in"), "x\n")
        File.write(File.join(dir, "#{cn}.sol"), "y\n")
      end
      File.write(File.join(dir, "config.yml"), <<~YAML)
        ---
        score_type: group_min
        testcases:
          1-1: { group: 1, group_name: 'g1', weight: 10 }
          1-2: { group: 1, group_name: 'g1', weight: 20 }
      YAML
      pi = import_example(dir, "mixed_w", do_solutions: false)
      assert pi.log.any? { |l| l =~ /WARNING.*group 1.*mixed/ },
             "expected mixed-weight warning, log was: #{pi.log.inspect}"
    end
  end
end
