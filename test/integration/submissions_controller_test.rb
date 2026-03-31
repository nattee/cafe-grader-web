require "test_helper"

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get submission_path(submissions(:add1_by_admin))
    assert_redirected_to login_main_path
  end

  test "user can view own submission" do
    sign_in_as("admin", "admin")
    get submission_path(submissions(:add1_by_admin))
    assert_response :success
  end

  test "user can list submissions by problem" do
    sign_in_as("admin", "admin")
    get problem_submissions_path(problem_id: problems(:prob_add).id)
    assert_response :success
  end

  test "user can download own submission" do
    sign_in_as("admin", "admin")
    get download_submission_path(submissions(:add1_by_admin))
    assert_response :success
  end

  # --- Permissions ---

  test "normal user cannot rejudge" do
    sign_in_as("john", "hello")
    sub = submissions(:add1_by_admin)
    get rejudge_submission_path(sub)
    assert_redirected_to list_main_path
  end

  # --- Direct edit ---

  test "user can access direct edit for viewable problem" do
    sign_in_as("john", "hello")
    prob = problems(:prob_add)
    get direct_edit_problem_submissions_path(problem_id: prob.id)
    assert_response :success
  end
end
