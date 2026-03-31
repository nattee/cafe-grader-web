require "test_helper"

class ReportControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected" do
    get "/report/max_score"
    assert_redirected_to login_main_path
  end

  test "normal user is redirected from reports" do
    sign_in_as("john", "hello")
    get "/report/max_score"
    assert_redirected_to list_main_path
  end

  test "admin can access max_score report" do
    sign_in_as("admin", "admin")
    get "/report/max_score"
    assert_response :success
  end

  test "admin can access login report" do
    sign_in_as("admin", "admin")
    get "/report/login"
    assert_response :success
  end

  test "admin can access submission report" do
    sign_in_as("admin", "admin")
    get "/report/submission"
    assert_response :success
  end
end
