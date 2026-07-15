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
end
