module Llm
  # Shared transport for a hosted OpenAI-compatible gateway that authenticates
  # with a static bearer key — a LiteLLM proxy, OpenRouter, or any aggregator
  # speaking /v1/chat/completions (the backlog "OpenRouter LLM provider"
  # sketch; placement per doc/decisions.md 2026-07-30: generic provider code
  # lives on master, dormant until configuration activates it).
  #
  # Everything deployment-specific is config, never code:
  # * config/llm.yml `ai_gateway:` — base_url, paths, display_name, the
  #   served-model roster, and (per-role) default models
  # * Rails credentials `llm.ai_gateway.api_key` — the bearer key; it must
  #   never appear in llm.yml, which is checked in
  #
  # Include into one concrete subclass per role (AiGatewayAssist,
  # VivaTurnAiGatewayAssist, ...). The subclass declares GATEWAY_ROLE — the
  # `default_models:` key it resolves its default from — and inherits:
  # * execute_call — bearer-auth POST of the prepared payload
  # * the PDF wire fix — the app builds PDF parts as bare-string image_url
  #   data URIs (Request.encode_pdf_part); LiteLLM maps image_url onto
  #   provider image blocks, which Anthropic rejects for PDFs (400, verified
  #   live 2026-08-26) while Gemini happens to accept. Both accept the OpenAI
  #   `file` part, so every PDF part is rewritten to that shape before POST.
  # * compute_cost — the gateway reports authoritative per-call USD in the
  #   x-litellm-response-cost response header; no hand-kept rate tables.
  module AiGatewayTransport
    class ConfigError < StandardError; end

    # The gateway itself gives up at 10 minutes; match it rather than cutting
    # long reasoning generations off at the stock 300s.
    READ_TIMEOUT = 600

    def self.included(base) = base.extend(ClassMethods)

    # Rewrite (in place) every PDF content part from the app's internal wire
    # shape into the OpenAI `file` part. Non-PDF parts and string-content
    # messages pass through untouched.
    def self.convert_pdf_parts(payload)
      return payload unless payload.is_a?(Hash) && payload[:messages].is_a?(Array)
      count = 0
      payload[:messages].each do |msg|
        next unless msg[:content].is_a?(Array)
        msg[:content].each do |part|
          next unless part.is_a?(Hash) && part[:type].to_s == 'image_url'
          uri = part[:image_url].is_a?(Hash) ? part[:image_url][:url] : part[:image_url]
          next unless uri.is_a?(String) && uri.start_with?('data:application/pdf')
          count += 1
          part.replace(type: 'file', file: {filename: "document-#{count}.pdf", file_data: uri})
        end
      end
      payload
    end

    module ClassMethods
      def gateway_config
        cfg = Rails.configuration.llm[:ai_gateway]
        raise ConfigError, 'config/llm.yml: ai_gateway is not configured' if cfg.blank?
        cfg
      end

      def gateway_api_key
        key = Rails.application.credentials.dig(:llm, :ai_gateway, :api_key)
        raise ConfigError, 'Rails credentials: llm.ai_gateway.api_key is missing (bin/rails credentials:edit)' if key.blank?
        key
      end

      # The served-model roster as strings — allowlist for caller-supplied
      # models and source for admin pickers (e.g. VivaGrade KNOWN_MODELS).
      def gateway_models = Array(gateway_config[:models]).map(&:to_s)

      # Console utility: fetch and pretty-print the gateway's live model
      # list. Mirrors Llm::GenieAssist.list_model.
      def list_model
        cfg = gateway_config
        response = Llm::Request.connection(cfg[:base_url]).get(cfg[:models_path] || '/v1/models') do |req|
          req.headers['Authorization'] = "Bearer #{gateway_api_key}"
        end
        models = JSON.parse(response.body)
        puts JSON.pretty_generate(models)
        models
      end
    end

    private

    # Backfill the configured default into bases that manage @model
    # (CommentAssist and the viva/grounding families set it from a
    # DEFAULT_MODEL constant, nil on master). Bases without an @model
    # (SubmissionRepairAssist resolves lazily) are left alone.
    def initialize(**args)
      super
      @model = gateway_default_model if defined?(@model) && @model.blank?
    end

    def provider_name
      self.class.gateway_config[:display_name].presence || 'AI Gateway'
    end

    # default_models[GATEWAY_ROLE] when set, else the shared default_model.
    def gateway_default_model
      cfg = self.class.gateway_config
      model = (cfg[:default_models] || {})[self.class::GATEWAY_ROLE].presence ||
              cfg[:default_model].presence
      raise ConfigError, 'config/llm.yml ai_gateway: no default_model configured' if model.blank?
      model.to_s
    end

    def execute_call(data)
      payload = data.is_a?(String) ? JSON.parse(data, symbolize_names: true) : data
      AiGatewayTransport.convert_pdf_parts(payload)
      cfg  = self.class.gateway_config
      conn = Llm::Request.connection(cfg[:base_url], read_timeout: READ_TIMEOUT)
      response = conn.post(cfg[:completion_path] || '/v1/chat/completions') do |req|
        req.headers['Authorization'] = "Bearer #{self.class.gateway_api_key}"
        req.body = payload
      end
      @gateway_response_cost = response.headers['x-litellm-response-cost'].to_f if response.respond_to?(:headers)
      response
    end

    # The gateway's own accounting for the most recent call (0.0 when the
    # header is absent). Repair calls this once per round, right after each
    # execute_chat, so last-call semantics are exactly right there too.
    def compute_cost(_usage)
      @gateway_response_cost.to_f
    end
  end
end
