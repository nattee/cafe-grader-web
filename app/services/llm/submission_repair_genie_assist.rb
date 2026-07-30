module Llm
  # Chula Genie concrete repair provider (chula_cp-only, like every Genie
  # class — provider placement per doc/decisions.md 2026-07-30). The engine
  # hands execute_chat a messages array; we wrap it in the same wire shape
  # CommentAssist speaks (model/messages/stream JSON + bearer token) against
  # the Genie relay. Genie accepts PDF statement parts (bare-string
  # image_url), so the engine's default include_statement_pdf? stays true.
  class SubmissionRepairGenieAssist < SubmissionRepairAssist
    DEFAULT_MODEL = 'gemini-2.5-pro'.freeze
    PERMITTED_MODEL = ['gemini-2.5-pro', 'gemini-2.5-flash'].freeze

    # Genie-relayed Gemini 2.5 Pro list pricing (USD per 1K tokens); the
    # relay's internal accounting may differ — treat as an estimate.
    COST_PER_1K_IN  = 0.00125
    COST_PER_1K_OUT = 0.01

    private

    def provider_name = 'Chula Genie'

    # SERVICE=/model_key selects within the permitted list; anything else
    # (including a self-host key left over in a command line) falls back to
    # the default rather than erroring — mirrors GenieAssist's guard.
    def resolved_model
      @resolved_model ||= begin
        m = @other_args[:model_key].presence
        PERMITTED_MODEL.include?(m) ? m : DEFAULT_MODEL
      end
    end

    def model_name_for_record = resolved_model

    def request_body(messages)
      {model: resolved_model, messages: messages, stream: false}.to_json
    end

    def execute_chat(messages)
      token = Llm::TokenManager.fetch_chula_genie_token
      raise 'Could not obtain authentication token for ChulaGenie' unless token

      genie = Rails.application.credentials.llm.genie
      conn  = Llm::Request.connection(genie[:host])
      conn.post(genie[:completion_path]) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.body = request_body(messages)
      end
    end

    def compute_cost(usage)
      ((usage['prompt_tokens'].to_i / 1000.0) * COST_PER_1K_IN) +
        ((usage['completion_tokens'].to_i / 1000.0) * COST_PER_1K_OUT)
    end
  end
end
