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
end
