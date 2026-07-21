module Llm
  # Chula Genie concrete subclass for grounding PDF->markdown extraction
  # (design D4). Inherits the extraction contract / draft handling from
  # Llm::GroundingExtractAssist; only the HTTP/auth call and pricing are
  # provider-specific. Mirrors Llm::VivaGradeGenieAssist#execute_call.
  #
  # DEPLOYMENT-SPECIFIC (chula_cp only, like the other Genie subclasses):
  # config/llm.yml's grounding_extract_service names this class here and is
  # blank on master.
  class GroundingExtractGenieAssist < GroundingExtractAssist
    # Flash handles multimodal PDF reading well and drafts are always
    # author-reviewed, so the cheap model is the right default. Bump to
    # gemini-2.5-pro per-call if a deck extracts poorly.
    DEFAULT_MODEL = 'gemini-2.5-flash'.freeze

    COST_PER_1K_IN  = 0.0003
    COST_PER_1K_OUT = 0.0025

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
