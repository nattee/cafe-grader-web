require "swagger_helper"

RSpec.describe "Testcases API", type: :request do
  fixtures :users, :roles, :grader_configurations, :sites,
           :problems, :datasets, :testcases,
           :groups, :groups_users, :groups_problems,
           :contests, :contests_users, :contests_problems

  let(:Authorization) { "Bearer #{jwt_token_for(users(:admin))}" }

  path "/api/v1/testcases/{id}/input" do
    get "Download testcase input file" do
      tags "Testcases"
      produces "text/plain"
      security [bearer: []]

      parameter name: :id, in: :path, type: :integer, required: true

      response "403", "not allowed to view testcase" do
        let(:user) { users(:john) }
        let(:Authorization) { "Bearer #{jwt_token_for(user)}" }
        let(:id) { testcases(:tc_add_1).id }

        # right.view_testcase is false in fixtures
        run_test!
      end
    end
  end

  path "/api/v1/testcases/{id}/sol" do
    get "Download testcase solution file" do
      tags "Testcases"
      produces "text/plain"
      security [bearer: []]

      parameter name: :id, in: :path, type: :integer, required: true

      response "403", "not allowed to view testcase" do
        let(:user) { users(:john) }
        let(:Authorization) { "Bearer #{jwt_token_for(user)}" }
        let(:id) { testcases(:tc_add_1).id }

        run_test!
      end
    end
  end
end
