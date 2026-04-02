require "swagger_helper"

RSpec.describe "Auth API", type: :request do
  fixtures :users, :roles, :grader_configurations, :sites

  path "/api/v1/auth/login" do
    post "Log in and receive a JWT token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          login: { type: :string, description: "Username" },
          password: { type: :string, description: "Password" }
        },
        required: %w[login password]
      }

      response "200", "login successful" do
        schema type: :object, additionalProperties: false, properties: {
          token: { type: :string, description: "JWT token" },
          user: {
            type: :object, additionalProperties: false,
            properties: {
              id: { type: :integer },
              login: { type: :string },
              full_name: { type: :string }
            }
          }
        }, required: %w[token user]

        let(:body) { { login: "admin", password: "admin" } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["token"]).to be_present
          expect(data["user"]["login"]).to eq("admin")
        end
      end

      response "401", "invalid credentials" do
        schema type: :object, additionalProperties: false, properties: { error: { type: :string } }

        let(:body) { { login: "admin", password: "wrong" } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]).to eq("Invalid login or password")
        end
      end
    end
  end
end
