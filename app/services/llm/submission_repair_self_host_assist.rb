module Llm
  # Self-hosted concrete repair provider. Model selection is pure config:
  # model_key (rake SERVICE=) -> self_hosted_models entry, default from
  # self_hosted_default. Dollar cost is 0.0 on department hardware; token
  # counts are still recorded by the base engine.
  class SubmissionRepairSelfHostAssist < SubmissionRepairAssist
    private

    def provider_name = 'self-host'

    def chat_client
      @chat_client ||= SelfHostChat.new(model_key: @other_args[:model_key])
    end

    def execute_chat(messages)
      chat_client.chat(messages)
    end

    def model_name_for_record = chat_client.model_name
  end
end
