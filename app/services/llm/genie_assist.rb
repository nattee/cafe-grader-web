module Llm
  # Chula Genie concrete subclass for comment-on-submission. Speaks the
  # OpenAI-compatible chat-completion shape that Llm::CommentAssist already
  # builds; the only provider-specific bits are auth (bearer token) + endpoint
  # (configured via Rails credentials llm.genie) + the permitted-models guard.
  class GenieAssist < CommentAssist
    PERMITTED_MODEL = ["gemini-2.5-pro", "gemini-2.5-flash", "Claude-3.5-Sonnet", "Claude-3.5-Haiku"]
    DEFAULT_MODEL   = "gemini-2.5-pro".freeze

    private

    def provider_name
      'Chula Genie'
    end

    # Override to enforce the permitted-models allowlist; an unrecognized
    # caller-supplied model is silently downgraded to the first permitted one.
    def prepare_data
      @model = PERMITTED_MODEL.first unless PERMITTED_MODEL.include?(@model)
      super
    end

    def execute_call(data)
      token = Llm::TokenManager.fetch_chula_genie_token
      raise RuntimeError, "Could not obtain authentication token for ChulaGenie" unless token

      genie = Rails.application.credentials.llm.genie
      conn  = Llm::Request.connection(genie[:host])
      conn.post(genie[:completion_path]) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.body = data
      end
    end

    # --- admin utility (not part of the LLM call template) ---

    # Calls the Genie API to list available models and pretty-prints them.
    # Useful from the Rails console when debugging which models a deployment
    # has access to.
    def self.list_model
      token = Llm::TokenManager.fetch_chula_genie_token
      unless token
        puts "Could not obtain authentication token for ChulaGenie. Aborting."
        return nil
      end

      genie = Rails.application.credentials.llm.genie
      conn  = connection(genie[:host])
      response = conn.get(genie[:model_path]) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
      end

      if response.success?
        models = JSON.parse(response.body)
        puts "Successfully fetched models:"
        puts JSON.pretty_generate(models)
        models
      else
        puts "Error fetching models."
        puts "Status: #{response.status}"
        puts "Body: #{response.body}"
        nil
      end
    end
  end
end
