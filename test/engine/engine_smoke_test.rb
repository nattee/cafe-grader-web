require 'test_helper'

# EngineSmoke drives one real submission through compile -> evaluate every
# testcase -> score on this host, the way Grader#process_job_* do, so an
# operator can prove the grading engine works on a box before (or right
# after) a deploy. It regrades a real row, so its contract is: report what
# the chain produced, then put the submission back exactly as found — even
# when the chain raises. The engine classes are injected here so the test
# pins that contract without isolate; the classes' entry points are the
# real ones (get_compiler/compile, execute, get_scorer/process).
class EngineSmokeTest < ActiveSupport::TestCase
  class << self
    attr_accessor :calls
  end

  class FakeCompiler
    def self.get_compiler(_sub) = self
    def initialize(_worker_id, _box_id); end
    def compile(sub, _dataset)
      EngineSmokeTest.calls << [:compile, sub.id]
      sub.update_columns(status: Submission.statuses[:compilation_success])
      EngineResponse::Result.success(result_description: 'compiled')
    end
  end

  class FailingCompiler < FakeCompiler
    def compile(sub, _dataset)
      EngineSmokeTest.calls << [:compile, sub.id]
      sub.update_columns(status: Submission.statuses[:compilation_error], grader_comment: 'Compilation error')
      EngineResponse::Result.success(result_description: 'Compilation error')
    end
  end

  class FakeEvaluator
    def self.get_evaluator(_sub) = self
    def initialize(_worker_id, _box_id); end
    def execute(sub, testcase)
      EngineSmokeTest.calls << [:evaluate, testcase.id]
      Evaluation.find_or_create_by(submission: sub, testcase: testcase).update(result: :correct, score: 1)
      EngineResponse::Result.success(result_description: 'evaluated')
    end
  end

  class ExplodingEvaluator < FakeEvaluator
    def execute(_sub, _testcase) = raise('sandbox exploded')
  end

  class FakeScorer
    def self.get_scorer(_sub) = self
    def initialize(_worker_id, _box_id); end
    def process(sub, _dataset)
      EngineSmokeTest.calls << [:score, sub.id]
      sub.update_columns(status: Submission.statuses[:done], points: 100, grader_comment: 'PP', graded_at: Time.zone.now)
      EngineResponse::Result.success(result_description: 'scored')
    end
  end

  setup do
    EngineSmokeTest.calls = []
    @sub = submissions(:add1_by_admin)
    @sub.update_columns(status: Submission.statuses[:done], points: 40, grader_comment: 'P-', graded_at: Time.zone.parse('2026-01-01 10:00'))
    @snapshot = @sub.reload.slice('status', 'points', 'grader_comment', 'graded_at')
    @evaluations_before = Evaluation.where(submission: @sub).count
  end

  def smoke(**engines)
    EngineSmoke.new(@sub, box_id: 99, worker_id: 1,
                    **{compiler: FakeCompiler, evaluator: FakeEvaluator, scorer: FakeScorer}.merge(engines))
  end

  test 'runs compile, then every testcase, then score, and reports what the chain produced' do
    report = smoke.run

    tc_ids = @sub.problem.live_dataset.testcases.to_a.map(&:id)
    assert_equal [[:compile, @sub.id], *tc_ids.map { |id| [:evaluate, id] }, [:score, @sub.id]], EngineSmokeTest.calls
    assert_nil report.error
    assert_equal 'done', report.before[:status]
    assert_equal 40.0,   report.before[:points].to_f
    assert_equal 'done', report.after[:status]
    assert_equal 100.0,  report.after[:points].to_f
    assert_equal 'PP',   report.after[:grader_comment]
    assert_equal tc_ids.map { |id| [id, 'correct'] }, report.evaluations.map { |e| [e[:testcase_id], e[:result]] }
  end

  test 'puts the submission and its evaluations back as found after a clean run' do
    smoke.run

    assert_equal @snapshot, @sub.reload.slice('status', 'points', 'grader_comment', 'graded_at')
    assert_equal @evaluations_before, Evaluation.where(submission: @sub).count, 'evaluation rows created by the run are removed'
  end

  test 'restores the submission and reports the error when the chain raises' do
    report = smoke(evaluator: ExplodingEvaluator).run

    assert_kind_of RuntimeError, report.error
    assert_equal 'sandbox exploded', report.error.message
    assert_equal @snapshot, @sub.reload.slice('status', 'points', 'grader_comment', 'graded_at')
    assert_empty EngineSmokeTest.calls.select { |c| c.first == :score }, 'no score after an evaluate failure'
  end

  test 'stops after a compilation error and reports it' do
    report = smoke(compiler: FailingCompiler).run

    assert_equal [[:compile, @sub.id]], EngineSmokeTest.calls
    assert_equal 'compilation_error', report.after[:status]
    assert_empty report.evaluations
    assert_equal @snapshot, @sub.reload.slice('status', 'points', 'grader_comment', 'graded_at')
  end
end
