require "test_helper"

class Replay::CmsReplayTest < ActiveSupport::TestCase
  C = Replay::CmsReplay

  # --- verdict_char -------------------------------------------------------

  test "outcome >= 1.0 is P regardless of text" do
    assert_equal "P", C.verdict_char(1.0, "anything")
    assert_equal "P", C.verdict_char(1, "")
    assert_equal "P", C.verdict_char(1.5, "Output is correct") # a checker could in theory emit >1.0
  end

  test "text matching timed out is T" do
    assert_equal "T", C.verdict_char(0.0, "Execution timed out")
    assert_equal "T", C.verdict_char(0.0, "Execution timed out (wall clock limit exceeded)")
  end

  test "text matching killed or memory is x (segfault/signal or MLE, cafe's combined bucket)" do
    assert_equal "x", C.verdict_char(0.0, "Execution killed (could be triggered by violating memory limits)")
    assert_equal "x", C.verdict_char(0.0, "Execution killed with signal 11")
  end

  test "a fractional outcome with no matching text is partial credit s" do
    assert_equal "s", C.verdict_char(0.5, "Output is partially correct")
  end

  test "zero outcome with no matching text is wrong answer -" do
    assert_equal "-", C.verdict_char(0.0, "Output isn't correct")
    assert_equal "-", C.verdict_char(0.0, "")
  end

  test "list-shaped text (CMS's format-template + args ARRAY column) is handled" do
    # extract_submissions.py already normalises Evaluation.text (a Postgres
    # ARRAY) to a joined String before it reaches Ruby -- but verdict_char
    # itself must not assume a bare String, since a caller could still hand
    # it the raw CMS list shape (a hand-built test fixture, or a future
    # extractor revision).
    assert_equal "T", C.verdict_char(0.0, ["Execution timed out"])
    assert_equal "x", C.verdict_char(0.0, ["Execution killed (could be triggered by violating memory %s)", "limits"])
  end

  # --- cms_verdict_string --------------------------------------------------

  def build_dataset(group_sizes)
    problem = Problem.create!(name: "cmsreplay_#{SecureRandom.hex(3)}", full_name: "CMS replay fixture")
    dataset = Dataset.create!(problem: problem, name: "D1")
    num = 0
    group_sizes.each_with_index do |count, gi|
      count.times do |i|
        num += 1
        Testcase.create!(dataset: dataset, problem: problem, num: num, group: gi + 1,
                         code_name: format("%02d-%02d", gi + 1, i + 1), weight: 1)
      end
    end
    dataset
  end

  test "cms_verdict_string builds in num order and maps each testcase via code_name" do
    dataset = build_dataset([2, 1]) # codenames 01-01, 01-02, 02-01 in num order
    evaluations = {
      "01-01" => { "outcome" => 1.0, "text" => "Output is correct" },
      "01-02" => { "outcome" => 0.0, "text" => "Execution timed out" },
      "02-01" => { "outcome" => 0.4, "text" => "Output is partially correct" }
    }
    assert_equal "PTs", C.cms_verdict_string(evaluations, dataset)
  end

  test "cms_verdict_string follows num order even when it disagrees with code_name's lexicographic order" do
    # code_name "9-1" sorts AFTER "10-1" lexicographically, but num order
    # must win -- the whole point of walking testcases.order(:num) instead
    # of trusting codename string-sort.
    problem = Problem.create!(name: "cmsreplay_#{SecureRandom.hex(3)}", full_name: "Order fixture")
    dataset = Dataset.create!(problem: problem, name: "D1")
    Testcase.create!(dataset: dataset, problem: problem, num: 1, group: 1, code_name: "9-1", weight: 1)
    Testcase.create!(dataset: dataset, problem: problem, num: 2, group: 2, code_name: "10-1", weight: 1)
    evaluations = {
      "9-1"  => { "outcome" => 1.0, "text" => "" },
      "10-1" => { "outcome" => 0.0, "text" => "" }
    }
    assert_equal "P-", C.cms_verdict_string(evaluations, dataset)
  end

  test "cms_verdict_string raises a clear, testcase-identifying error on a missing codename rather than padding" do
    dataset = build_dataset([2])
    evaluations = { "01-01" => { "outcome" => 1.0, "text" => "" } } # "01-02" is missing
    err = assert_raises(RuntimeError) { C.cms_verdict_string(evaluations, dataset) }
    assert_match(/01-02/, err.message)
    assert_match(/#2/, err.message)
  end

  test "cms_verdict_string tolerates symbol-keyed evaluations and per-evaluation hashes" do
    dataset = build_dataset([1])
    evaluations = { "01-01" => { outcome: 1.0, text: "Output is correct" } }
    assert_equal "P", C.cms_verdict_string(evaluations, dataset)
  end
end
