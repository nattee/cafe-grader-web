module Llm
  # Chula Genie concrete subclass for viva interview turns. Inherits message/response
  # handling from Llm::VivaTurnAssist; only the HTTP/auth call and pricing are
  # provider-specific. Mirrors the POST pattern in Llm::GenieAssist#execute_call.
  class VivaTurnGenieAssist < VivaTurnAssist
    DEFAULT_MODEL = 'gemini-2.5-flash'.freeze

    # Chula Genie-relayed Gemini 2.5 Flash pricing (USD per 1K tokens).
    COST_PER_1K_IN  = 0.0003
    COST_PER_1K_OUT = 0.0025

    private

    def provider_name
      'Chula Genie'
    end

    def execute_call(data)
      token = Llm::TokenManager.fetch_chula_genie_token
      unless token
        @error = 'Could not obtain authentication token for ChulaGenie. Aborting.'
        handle_error
        return nil
      end

      genie = Rails.application.credentials.llm.genie
      conn  = SubmissionAssist.connection(genie[:host])
      conn.post(genie[:completion_path]) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.body = data
      end
    end

    def compute_cost(usage)
      ((usage['prompt_tokens'].to_i / 1000.0) * COST_PER_1K_IN) +
        ((usage['completion_tokens'].to_i / 1000.0) * COST_PER_1K_OUT)
    end
  end
end
