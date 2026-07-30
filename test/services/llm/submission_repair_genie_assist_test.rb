require 'test_helper'

# Network-free coverage of the Genie repair provider's pure parts: wire-body
# shape, model resolution, cost math, and the PDF flag. The HTTP/auth path
# mirrors the other (untested-by-convention) Genie transports.
class Llm::SubmissionRepairGenieAssistTest < ActiveSupport::TestCase
  setup do
    @submission = submissions(:add1_by_john)
    @repair = SubmissionRepair.create!(original_submission: @submission,
                                       budget_lines: 2, budget_chars: 20, run_label: 't')
  end

  def service(**args)
    Llm::SubmissionRepairGenieAssist.new(submission: @submission, repair: @repair, **args)
  end

  test 'request body speaks the Genie wire shape with the default model' do
    body = JSON.parse(service.send(:request_body, [{role: 'user', content: 'x'}]))
    assert_equal 'gemini-2.5-pro', body['model']
    assert_equal false, body['stream']
    assert_equal [{'role' => 'user', 'content' => 'x'}], body['messages']
  end

  test 'model_key selects within the permitted list, anything else falls back' do
    assert_equal 'gemini-2.5-flash', service(model_key: 'gemini-2.5-flash').send(:resolved_model)
    assert_equal 'gemini-2.5-pro', service(model_key: 'qwen3.5').send(:resolved_model)
    assert_equal 'gemini-2.5-pro', service.send(:model_name_for_record)
  end

  test 'cost math uses the per-1K rates' do
    cost = service.send(:compute_cost, {'prompt_tokens' => 1000, 'completion_tokens' => 1000})
    assert_in_delta 0.01125, cost, 1e-9
  end

  test 'Genie keeps the statement PDF in the prompt' do
    assert service.send(:include_statement_pdf?)
  end
end
