require "test_helper"

class GradersControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected" do
    get grader_processes_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected" do
    sign_in_as("john", "hello")
    get grader_processes_path
    assert_redirected_to list_main_path
  end

  test "admin can access graders" do
    sign_in_as("admin", "admin")
    get grader_processes_path
    assert_response :success
  end
end
