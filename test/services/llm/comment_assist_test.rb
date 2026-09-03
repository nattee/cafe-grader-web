require 'test_helper'

class Llm::CommentAssistTest < ActiveSupport::TestCase
  setup do
    @submission = submissions(:add1_by_john)
    @submission.problem.tags.create!(name: 'ca-prompt', kind: 'llm_prompt', params: 'You are a tutor.')
  end

  test "payload has no null content parts when the problem has no statement PDF" do
    refute @submission.problem.statement.attached?, 'fixture problem must have no PDF for this test'
    data = Llm::CommentAssist.preview(submission: @submission, comment: Comment.new, model: 'x')
    user_parts = data[:messages].last[:content]
    assert user_parts.all? { |p| p.is_a?(Hash) && p[:type].present? },
           "a nil part leaked into the user content: #{user_parts.inspect}"
    assert user_parts.any? { |p| p[:text].to_s.include?('source code of the student') }
  end

  # --- payload context: what the grader already knows ---

  def preview_user_text(sub = @submission, comment: Comment.new)
    data = Llm::CommentAssist.preview(submission: sub, comment: comment, model: 'x')
    data[:messages].last[:content].select { |p| p[:type] == 'text' }.map { |p| p[:text] }.join("\n")
  end

  test "compile error: payload carries the compiler output" do
    @submission.update_columns(status: Submission.statuses[:compilation_error], grader_comment: 'Compilation error',
                               compiler_message: "main.c:4: error: expected ';' before '}'")
    text = preview_user_text
    assert_includes text, "expected ';' before '}'"
    assert_includes text, 'did not compile'
  end

  test "graded: payload carries the per-testcase table built from evaluations" do
    @submission.evaluations.create!(testcase: testcases(:tc_add_1), result: :correct,    time: 12,   memory: 3072, score: 1.0)
    @submission.evaluations.create!(testcase: testcases(:tc_add_2), result: :time_limit, time: 1000, memory: 3072, score: 0.0)
    @submission.update_columns(status: Submission.statuses[:done], grader_comment: 'PT', points: 50)
    text = preview_user_text
    assert_includes text, 'Per-testcase results'
    assert_match(/^\| 1 \|.*\bcorrect\b/m, text)
    assert_match(/^\| 2 \|.*\btime_limit\b/m, text)
    assert_match(/time limit/i, text)   # the dataset limits are stated
  end

  test "ungraded: no per-testcase table, the verdict string is still sent" do
    text = preview_user_text
    refute_includes text, 'Per-testcase results'
    assert_includes text, 'source code of the student'
  end

  test "repeat request: payload carries the previous answer and the diff against that submission" do
    earlier = Submission.new(user: users(:john), problem: @submission.problem, language: @submission.language,
                             source: "int main() {\n  return 1;\n}\n", submitted_at: @submission.submitted_at - 1.hour)
    earlier.save!(validate: false)
    earlier.comments.create!(user: users(:john), kind: 'llm_assist', status: 'ok', llm_model: 'x', cost: 10,
                             title: 'Assistance by x', body: 'Check your loop bound.')
    @submission.update_columns(source: "int main() {\n  return 0;\n}\n")
    text = preview_user_text
    assert_includes text, 'Check your loop bound.'
    assert_includes text, "-  return 1;"
    assert_includes text, "+  return 0;"
    assert_includes text, 'request number 2'
  end

  test "first request: no previous-answer block" do
    refute_includes preview_user_text, 'previous answer'
  end

  # --- accounting ---

  class CostedAssist < Llm::CommentAssist
    private
    def provider_name = 'costed'
    def compute_cost(_usage) = 0.0123
  end

  class UncostedAssist < Llm::CommentAssist
    private
    def provider_name = 'uncosted'
  end

  FakeResponse = Struct.new(:body)

  def processing_comment
    @submission.comments.create!(user: users(:john), kind: 'llm_assist', title: 't', body: 'b', cost: 0, status: 'processing')
  end

  test "handle_response records prompt/completion tokens and the provider's dollar cost" do
    comment = processing_comment
    body = {choices: [{message: {content: 'hint'}}], usage: {prompt_tokens: 3450, completion_tokens: 5591}}.to_json
    CostedAssist.new(submission: @submission, comment: comment, model: 'm').send(:handle_response, FakeResponse.new(body))
    comment.reload
    assert_equal 3450, comment.prompt_tokens
    assert_equal 5591, comment.completion_tokens
    assert_in_delta 0.0123, comment.llm_cost.to_f, 1e-9
    assert_equal Llm::CommentAssist::ASSIST_COST, comment.cost, 'score penalty is a separate column'
  end

  test "handle_response leaves llm_cost nil for a provider without a cost source; tokens still recorded" do
    comment = processing_comment
    body = {choices: [{message: {content: 'hint'}}], usage: {prompt_tokens: 3450, completion_tokens: 5591}}.to_json
    UncostedAssist.new(submission: @submission, comment: comment, model: 'm').send(:handle_response, FakeResponse.new(body))
    comment.reload
    assert_nil comment.llm_cost
    assert_equal 3450, comment.prompt_tokens
  end

  # --- system prompt assembly from tags ---

  test "several llm_prompt tags become separate system parts in name order" do
    @submission.problem.tags.create!(name: 'codey-thai', kind: 'llm_prompt', params: 'Append a Thai translation.')
    @submission.problem.tags.create!(name: 'codey-core', kind: 'llm_prompt', params: 'You are Codey.')
    data = Llm::CommentAssist.preview(submission: @submission, comment: Comment.new, model: 'x')
    texts = data[:messages].first[:content].map { |p| p[:text] }
    # ca-prompt < codey-core < codey-thai by name, although codey-thai was attached first
    assert_equal ['You are a tutor.', 'You are Codey.', 'Append a Thai translation.'], texts
  end
end
