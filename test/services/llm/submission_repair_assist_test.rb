require 'test_helper'

class Llm::SubmissionRepairAssistTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:body)

  # Scripted provider: pops one reply per round. Records every messages
  # array it was called with.
  class ScriptedRepair < Llm::SubmissionRepairAssist
    attr_reader :calls
    def script=(replies)
      @script = replies.dup
      @calls = []
    end
    private
    def provider_name = 'scripted'
    def model_name_for_record = 'fake-model'
    def execute_chat(messages)
      @calls << messages.map { |m| m[:role] }
      reply = @script.shift or raise 'script exhausted'
      body = {choices: [{message: {content: reply}}],
              usage: {prompt_tokens: 100, completion_tokens: 50}}.to_json
      FakeResponse.new(body)
    end
  end

  GOOD_REPLY = <<~R
    CATEGORY: io_format
    REASON: print newline instead of space
    ```c
    int main(){printf("%d\\n",42);}
    ```
  R

  setup do
    @submission = submissions(:add1_by_john)
    @submission.update_columns(status: Submission.statuses[:done], points: 0)
    @submission.update_columns(source: %(int main(){printf("%d ",42);}))
    @repair = SubmissionRepair.create!(original_submission: @submission,
                                       budget_lines: 2, budget_chars: 20, run_label: 't')
  end

  def run_scripted(*replies, rounds: 3)
    svc = ScriptedRepair.new(submission: @submission, repair: @repair, rounds: rounds)
    svc.script = replies
    first = svc.send(:execute_chat, svc.send(:initial_messages))
    svc.send(:prepare_data)
    svc.send(:handle_response, first)
    svc
  end

  test "within-budget fix -> accepted, shadow created, judge job enqueued at -60" do
    assert_difference -> { Submission.shadow.count } => 1, -> { Job.count } => 1 do
      run_scripted(GOOD_REPLY)
    end
    @repair.reload
    assert @repair.accepted?
    shadow = @repair.repaired_submission
    assert_equal @submission.id, shadow.repaired_from_id
    assert_includes shadow.source, '\n'
    assert_equal 'io_format', @repair.fix_category
    assert_equal 1, @repair.rounds_used
    assert_equal 100, @repair.token_count_in
    assert_equal 50, @repair.token_count_out
    assert_equal 'fake-model', @repair.llm_model
    assert_equal 'accepted', @repair.rounds_log.last['gate']
    job = Job.order(:id).last
    assert_equal shadow.id, job.arg.to_i
    assert_equal(-60, job.priority)
  end

  test "over-budget then within-budget -> retry with feedback, accepted in round 2" do
    huge = "CATEGORY: logic\nREASON: rewrite\n```c\n" + ("x" * 500) + "\n```\n"
    svc = run_scripted(huge, GOOD_REPLY)
    assert @repair.reload.accepted?
    assert_equal 2, @repair.rounds_used
    assert_equal %w[over_budget accepted], @repair.rounds_log.map { |r| r['gate'] }
    # round-2 call must carry assistant reply + corrective user feedback
    assert_equal %w[system user assistant user], svc.calls.last
  end

  test "persistently over budget -> over_budget after rounds exhausted" do
    huge = "```c\n" + ("y" * 500) + "\n```\n"
    run_scripted(huge, huge, huge)
    @repair.reload
    assert @repair.over_budget?
    assert_equal 3, @repair.rounds_used
    assert_equal 0, Submission.shadow.count
  end

  test "UNFIXABLE -> no_change" do
    run_scripted("UNFIXABLE")
    assert @repair.reload.no_change?
  end

  test "never parseable -> failed (not over_budget)" do
    run_scripted("no code here", "still nothing", "nope")
    assert @repair.reload.failed?
  end

  test "identical file returned -> no_change" do
    same = "```c\n#{@submission.source}\n```"
    run_scripted(same)
    assert @repair.reload.no_change?
  end

  test "rounds parameter caps the loop" do
    huge = "```c\n" + ("z" * 500) + "\n```\n"
    run_scripted(huge, rounds: 1)
    assert @repair.reload.over_budget?
    assert_equal 1, @repair.rounds_used
  end

  test "job resolves service from config with abstract fallback" do
    prev = Rails.configuration.llm[:submission_repair_service]
    Rails.configuration.llm[:submission_repair_service] = nil
    assert_equal Llm::SubmissionRepairAssist, Llm::SubmissionRepairJob.new.send(:service_class)
    Rails.configuration.llm[:submission_repair_service] = 'Llm::SubmissionRepairSelfHostAssist'
    assert_equal Llm::SubmissionRepairSelfHostAssist, Llm::SubmissionRepairJob.new.send(:service_class)
  ensure
    Rails.configuration.llm[:submission_repair_service] = prev
  end
end
