require "test_helper"

class ContestsAiUsageTest < ActionDispatch::IntegrationTest
  setup { @contest = contests(:contest_a) }

  test "unauthenticated is redirected" do
    get ai_usage_contest_path(@contest)
    assert_redirected_to login_main_path
  end

  test "plain user cannot view" do
    sign_in_as("john", "hello")
    get ai_usage_contest_path(@contest)
    assert_response :redirect
  end

  test "admin sees the AI usage page" do
    sign_in_as("admin", "admin")
    get ai_usage_contest_path(@contest)
    assert_response :success
  end

  test "editor of the contest sees the page" do
    sign_in_as("mary", "mary")     # mary is editor of group_a and contest_a
    get ai_usage_contest_path(@contest)
    assert_response :success
  end

  test "ai_usage_query returns a data array" do
    sign_in_as("admin", "admin")
    post ai_usage_query_contest_path(@contest)
    assert_response :success
    assert_kind_of Array, response.parsed_body["data"]
  end
end
