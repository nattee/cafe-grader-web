require "test_helper"

class Llm::VivaTurnAssistTest < ActiveSupport::TestCase
  setup do
    @submission = submissions(:add1_by_admin)
    @submission.viva_turns.destroy_all
    @placeholder = @submission.viva_turns.create!(role: :assistant, status: :processing)
    # Use the same in-memory Problem the assist will read via @submission.problem,
    # so update_columns calls below are visible to the assist without needing reload.
    @problem = @submission.problem
    # update_columns bypasses the after_save PDF-generation callback that we don't want firing in unit tests
    @problem.update_columns(description: "Scenario A\nScenario B")
    # Viva requires a non-blank viva_prompt (examiner briefing) on the problem;
    # assemble_system_prompt raises without it. Content doesn't matter for these tests.
    @problem.update!(viva_prompt: 'You are a viva interviewer.')
    @assist = Llm::VivaTurnAssist.new(submission: @submission, turn: @placeholder)
  end

  test "messages_array prepends description as first user message" do
    msgs = @assist.send(:messages_array)
    assert_equal 'system', msgs.first[:role]
    assert_equal 'user',   msgs[1][:role]
    assert_equal "Scenario A\nScenario B", msgs[1][:content]
  end

  test "first user message falls back to placeholder when description is blank" do
    @problem.update_columns(description: '')
    fresh = Llm::VivaTurnAssist.new(submission: @submission, turn: @placeholder)
    msgs  = fresh.send(:messages_array)
    assert_equal 'user', msgs[1][:role]
    assert_equal '(begin the interview)', msgs[1][:content]
  end

  test "student turns are remapped to role: user on the wire" do
    student = @submission.viva_turns.create!(role: :student, status: :ok, content: 'my answer')
    @submission.viva_turns.create!(role: :assistant, status: :ok, content: 'next question')
    msgs = @assist.send(:messages_array)

    # consolidate_role_runs merges the consecutive user turns (scenario + answer)
    user_msg      = msgs.find { |m| m[:role] == 'user' && m[:content].include?('my answer') }
    assistant_msg = msgs.find { |m| m[:role] == 'assistant' && m[:content] == 'next question' }
    assert user_msg,      'expected a user message containing "my answer"'
    assert assistant_msg, 'expected the assistant message'
    # sanity: DB row still has student role
    assert student.student?
  end

  test "current placeholder turn is excluded from the message list" do
    msgs = @assist.send(:messages_array)
    refute msgs.any? { |m| m[:content] == '' }, 'placeholder content should not appear'
    # only system + scenario user; nothing else yet
    assert_equal 2, msgs.length
  end

  test "system prompt is just viva_prompt content + [[VIVA_DONE]] directive" do
    sys = @assist.send(:assemble_system_prompt)
    # the test setup sets viva_prompt to 'You are a viva interviewer.'
    assert_includes sys, 'You are a viva interviewer.'
    assert_includes sys, '[[VIVA_DONE]]'
    # backend no longer injects scenario-handling guidance — that's the prompt's job
    refute_includes sys, 'first user message contains the scenario'
  end

  test 'system prompt layers in fixed order: conduct, briefing, security, done' do
    @problem.update!(viva_prompt: "# Rubric\ncorrectness: 100")
    @problem.tags << Tag.create!(name: 'b-conduct', kind: :viva_conduct, params: 'CONDUCT-B')
    @problem.tags << Tag.create!(name: 'a-conduct', kind: :viva_conduct, params: 'CONDUCT-A')
    svc = Llm::VivaTurnAssist.new(submission: @submission, turn: @placeholder)
    prompt = svc.send(:assemble_system_prompt)
    order = [prompt.index('CONDUCT-A'), prompt.index('CONDUCT-B'),
             prompt.index('# Rubric'), prompt.index('SECURITY'), prompt.index('[[VIVA_DONE]]')]
    assert_equal order.sort, order, "layers out of order: #{order.inspect}"
    assert order.all?, "a layer is missing: #{order.inspect}"
  end

  test "grounding material is added to first user message when grounding materials exist" do
    grounding = GroundingMaterial.create!(title: 'test_grounding', body: 'Reference: trees have nodes and edges.')
    @problem.grounding_materials << grounding

    msgs = @assist.send(:messages_array)
    user_msg = msgs[1]
    # With grounding, the first user message becomes a content array
    assert_kind_of Array, user_msg[:content]
    grounding_part = user_msg[:content].find { |p| p[:type] == 'text' && p[:text].include?('Grounding Material') }
    assert grounding_part, 'expected a Grounding Material text part in the first user message'
    assert_includes grounding_part[:text], 'trees have nodes'
  end

  test "handle_response raises ResponseError when choices array is empty" do
    response = Struct.new(:body).new('{"choices":[]}')
    err = assert_raises(Llm::Request::ResponseError) do
      @assist.send(:handle_response, response)
    end
    assert_match(/choices\[0\]\.message\.content/, err.message)
  end

  test "handle_response raises ResponseError when message content is missing" do
    response = Struct.new(:body).new('{"choices":[{"message":{}}]}')
    assert_raises(Llm::Request::ResponseError) do
      @assist.send(:handle_response, response)
    end
  end

  test "handle_response raises ResponseError when content is whitespace-only" do
    response = Struct.new(:body).new('{"choices":[{"message":{"content":"   \n  "}}]}')
    assert_raises(Llm::Request::ResponseError) do
      @assist.send(:handle_response, response)
    end
  end

  def alert_response_body(text)
    {choices: [{message: {content: text}}], model: 'stub', usage: {prompt_tokens: 1, completion_tokens: 1}}.to_json
  end

  test 'practice mode: alert logs a flag, injects notice, never terminates' do
    @problem.update!(viva_mode: :practice)
    svc = Llm::VivaTurnAssist.new(submission: @submission, turn: @placeholder)
    result = svc.send(:handle_response, Struct.new(:body).new(alert_response_body("deflection [[VIVA_ALERT]]")))
    refute result[:done]
    assert @placeholder.reload.alerted
    assert_nil @submission.reload.viva_terminated_at
    assert_equal 'submitted', @submission.status
    assert @submission.viva_turns.where(role: :system).last.content.include?('practice mode')
  end

  test 'exam mode: first strike warns, second terminates and grades' do
    @problem.update!(viva_mode: :exam)
    svc = Llm::VivaTurnAssist.new(submission: @submission, turn: @placeholder)
    r1 = svc.send(:handle_response, Struct.new(:body).new(alert_response_body("deflect [[VIVA_ALERT]]")))
    refute r1[:done]
    assert_nil @submission.reload.viva_terminated_at
    assert @submission.viva_turns.where(role: :system).last.content.include?('WARNING')

    turn2 = @submission.viva_turns.create!(role: :assistant, status: :processing, content: nil)
    svc2 = Llm::VivaTurnAssist.new(submission: @submission, turn: turn2)
    r2 = svc2.send(:handle_response, Struct.new(:body).new(alert_response_body("deflect again [[VIVA_ALERT]]")))
    assert r2[:done]
    assert @submission.reload.viva_terminated_at.present?
    assert_equal 'evaluating', @submission.status
  end

  test 'clean DONE still finishes without alert' do
    svc = Llm::VivaTurnAssist.new(submission: @submission, turn: @placeholder)
    result = svc.send(:handle_response, Struct.new(:body).new(alert_response_body("bye [[VIVA_DONE]]")))
    assert result[:done]
    refute @placeholder.reload.alerted
    assert_nil @submission.reload.viva_terminated_at
  end
end
