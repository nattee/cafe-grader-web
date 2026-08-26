require 'test_helper'
# Object#stub. Without this, credentials.stub(...) silently no-ops: the call
# falls into EncryptedConfiguration#method_missing, which ignores the block.
require 'minitest/mock'

class Llm::AiGatewayTransportTest < ActiveSupport::TestCase
  FAKE_CONFIG = {
    display_name: 'Test Gateway',
    base_url: 'http://gateway.test',
    completion_path: '/v1/chat/completions',
    models_path: '/v1/models',
    default_model: 'model-a',
    default_models: {viva_turn: 'model-b'},
    models: ['model-a', 'model-b']
  }.freeze

  FakeResponse = Struct.new(:body, :headers)

  # Captures posts without network. Mirrors the house style: hand-rolled
  # fakes over HTTP-stub gems.
  class FakeConnection
    attr_reader :posts
    def initialize(headers: {}) = (@posts = []; @response_headers = headers)
    def post(path)
      req = Struct.new(:headers, :body).new({}, nil)
      yield req
      @posts << [path, req]
      FakeResponse.new('{"choices":[{"message":{"content":"ok"}}]}', @response_headers)
    end
  end

  # Minimal hosts exercising the mixin without domain records. ProbeBase
  # stands in for the assist bases' @model management.
  class ProbeBase
    def initialize(model: nil) = @model = model
    def model = @model
  end

  class AssistProbe < ProbeBase
    include Llm::AiGatewayTransport
    GATEWAY_ROLE = :assist
  end

  class VivaTurnProbe < ProbeBase
    include Llm::AiGatewayTransport
    GATEWAY_ROLE = :viva_turn
  end

  def with_gateway_config(cfg = FAKE_CONFIG)
    prev = Rails.configuration.llm[:ai_gateway]
    Rails.configuration.llm[:ai_gateway] = cfg
    yield
  ensure
    Rails.configuration.llm[:ai_gateway] = prev
  end

  test "convert_pdf_parts rewrites PDF image_url parts to file blocks, leaves others" do
    payload = {
      model: 'model-a',
      messages: [
        {role: 'system', content: 'plain string content'},
        {role: 'user', content: [
          {type: 'text', text: 'look at this'},
          {type: 'image_url', image_url: 'data:application/pdf;base64,AAA'},
          {type: 'image_url', image_url: {url: 'data:application/pdf;base64,BBB'}},
          {type: 'image_url', image_url: 'data:image/png;base64,CCC'}
        ]}
      ]
    }
    Llm::AiGatewayTransport.convert_pdf_parts(payload)

    parts = payload[:messages][1][:content]
    assert_equal 'text', parts[0][:type]
    assert_equal({type: 'file', file: {filename: 'document-1.pdf', file_data: 'data:application/pdf;base64,AAA'}}, parts[1])
    assert_equal({type: 'file', file: {filename: 'document-2.pdf', file_data: 'data:application/pdf;base64,BBB'}}, parts[2])
    assert_equal 'image_url', parts[3][:type], 'non-PDF image parts must pass through'
    assert_equal 'plain string content', payload[:messages][0][:content]
  end

  test "execute_call posts transformed payload with bearer auth and captures the cost header" do
    with_gateway_config do
      fake = FakeConnection.new(headers: {'x-litellm-response-cost' => '0.00123'})
      json = {model: 'model-a',
              messages: [{role: 'user', content: [
                {type: 'image_url', image_url: 'data:application/pdf;base64,AAA'}
              ]}]}.to_json
      probe = AssistProbe.new(model: 'model-a')
      Rails.application.credentials.stub(:dig, 'sk-test') do
        Llm::Request.stub(:connection, fake) do
          probe.send(:execute_call, json)
        end
      end

      path, req = fake.posts.first
      assert_equal '/v1/chat/completions', path
      assert_equal 'Bearer sk-test', req.headers['Authorization']
      assert_equal 'file', req.body[:messages][0][:content][0][:type], 'JSON-string payloads must also get the PDF rewrite'
      assert_in_delta 0.00123, probe.send(:compute_cost, {}), 1e-9
    end
  end

  test "gateway_default_model prefers the role override and falls back to default_model" do
    with_gateway_config do
      assert_equal 'model-b', VivaTurnProbe.new(model: 'x').send(:gateway_default_model)
      assert_equal 'model-a', AssistProbe.new(model: 'x').send(:gateway_default_model)
    end
    with_gateway_config(FAKE_CONFIG.except(:default_model, :default_models)) do
      assert_raises(Llm::AiGatewayTransport::ConfigError) do
        AssistProbe.new(model: 'x').send(:gateway_default_model)
      end
    end
  end

  test "initialize backfills the configured default only when the base left @model blank" do
    with_gateway_config do
      assert_equal 'model-a', AssistProbe.new.model
      assert_equal 'model-b', VivaTurnProbe.new.model
      assert_equal 'explicit', AssistProbe.new(model: 'explicit').model
    end
  end

  test "provider_name and gateway_models come from config; unconfigured raises ConfigError" do
    with_gateway_config do
      assert_equal 'Test Gateway', AssistProbe.new.send(:provider_name)
      assert_equal ['model-a', 'model-b'], AssistProbe.gateway_models
    end
    with_gateway_config(nil) do
      assert_raises(Llm::AiGatewayTransport::ConfigError) { AssistProbe.gateway_config }
    end
  end
end
