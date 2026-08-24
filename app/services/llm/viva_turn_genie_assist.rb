module Llm
  # Chula Genie concrete subclass for viva interview turns. Inherits message/response
  # handling from Llm::VivaTurnAssist; only the HTTP/auth call and pricing are
  # provider-specific. Mirrors the POST pattern in Llm::GenieAssist#execute_call.
  class VivaTurnGenieAssist < VivaTurnAssist
    # Claude-Sonnet (relay-served claude-sonnet-4-5, unpinned) chosen
    # 2026-08-24 after replaying real practice-viva turns through five relay
    # models: only Sonnet never leaked an answer to the student (2.5-flash
    # and 3-flash both gave sub-answers away; Haiku lectured), it follows the
    # scenario script, matches the student's Thai, and sits on a GA model ID
    # — unlike the Gemini 3.x aliases, which the relay serves from retired or
    # retirable -preview IDs, and 2.5-flash, which Vertex retires ~2026-10-16.
    DEFAULT_MODEL = 'Claude-Sonnet'.freeze

    # Chula Genie-relayed Claude Sonnet 4.5 list pricing (USD per 1K tokens).
    COST_PER_1K_IN  = 0.003
    COST_PER_1K_OUT = 0.015

    private

    def provider_name
      'Chula Genie'
    end

    def execute_call(data)
      token = Llm::TokenManager.fetch_chula_genie_token
      raise RuntimeError, 'Could not obtain authentication token for ChulaGenie' unless token

      genie = Rails.application.credentials.llm.genie
      conn  = Llm::Request.connection(genie[:host])
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
