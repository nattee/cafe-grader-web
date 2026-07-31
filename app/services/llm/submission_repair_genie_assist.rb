module Llm
  # Chula Genie concrete repair provider (chula_cp-only, like every Genie
  # class — provider placement per doc/decisions.md 2026-07-30). The engine
  # hands execute_chat a messages array; we wrap it in the same wire shape
  # CommentAssist speaks (model/messages/stream JSON + bearer token) against
  # the Genie relay. Genie accepts PDF statement parts (bare-string
  # image_url), so the engine's default include_statement_pdf? stays true.
  class SubmissionRepairGenieAssist < SubmissionRepairAssist
    DEFAULT_MODEL = 'gemini-2.5-pro'.freeze

    # Permitted models with USD-per-1K [input, output] list-price estimates —
    # the relay's internal accounting may differ. Keys double as the
    # allowlist (checked live via Llm::GenieAssist.list_model, 2026-07-31).
    MODEL_RATES = {
      'gemini-2.5-pro'   => [0.00125, 0.01],
      'gemini-2.5-flash' => [0.0003, 0.0025],
      'gemini-3.1-pro'   => [0.002, 0.012],
      'Claude-Sonnet'    => [0.003, 0.015]
    }.freeze

    private

    def provider_name = 'Chula Genie'

    # SERVICE=/model_key selects within the permitted list; anything else
    # (including a self-host key left over in a command line) falls back to
    # the default rather than erroring — mirrors GenieAssist's guard.
    def resolved_model
      @resolved_model ||= begin
        m = @other_args[:model_key].presence
        MODEL_RATES.key?(m) ? m : DEFAULT_MODEL
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
      rate_in, rate_out = MODEL_RATES.fetch(resolved_model)
      ((usage['prompt_tokens'].to_i / 1000.0) * rate_in) +
        ((usage['completion_tokens'].to_i / 1000.0) * rate_out)
    end
  end
end
