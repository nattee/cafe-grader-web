require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Cafe Grader API",
        version: "v1",
        description: "API for the Cafe Grader online judge platform"
      },
      paths: {},
      servers: [
        { url: "{server}", variables: { server: { default: "https://your-server.example.com", description: "Server URL" } } }
      ],
      components: {
        securitySchemes: {
          bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
