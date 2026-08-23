module Llm
  # Chula Genie concrete subclass for viva grading. Inherits transcript/rubric
  # handling from Llm::VivaGradeAssist; only the HTTP/auth call and pricing are
  # provider-specific. Mirrors the POST pattern in Llm::GenieAssist#execute_call.
  class VivaGradeGenieAssist < VivaGradeAssist
    # gemini-3.1-pro chosen over 2.5-flash after a 12-session comparison on
    # real practice vivas (2026-08-23): agrees within flash's own ±10 rerun
    # noise on 9/11, and on both divergent sessions pro was right — flash
    # credited interviewer scaffolding as student knowledge (sub 937769) and
    # reproducibly role-played the next interview turn instead of emitting
    # the grade JSON (sub 937805). ~5x cost (~$0.034/grading), fine for batch.
    DEFAULT_MODEL = 'gemini-3.1-pro'.freeze

    # Chula Genie-relayed Gemini 3.1 Pro list-price estimates (USD per 1K).
    # Reasoning model: thinking tokens bill as output (~1.6k/grading observed).
    COST_PER_1K_IN  = 0.002
    COST_PER_1K_OUT = 0.012

    # Models accessible through Chula Genie's chat-completion endpoint. Drives
    # the admin "Re-run grading" model picker on /submissions/:id/viva.
    # Source: Llm::GenieAssist.list_model output (run from console, 2026-08-23).
    # If genie's roster changes, update this list — out-of-list values still
    # work if the admin types one in (the form's <select> doesn't enforce
    # exact match; the upstream rejects unknown models with a 4xx).
    KNOWN_MODELS = %w[
      gemini-3.1-pro
      gemini-3.1-flash-lite
      gemini-3-flash
      gemini-2.5-pro
      gemini-2.5-flash
      gemini-2.5-flash-lite
      gemini-2.0-flash
      gemini-2.0-flash-lite
      Claude-Sonnet
      Claude-Haiku
      gpt-4o-mini
    ].freeze

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
