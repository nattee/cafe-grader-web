require "test_helper"

class ProblemsControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get problems_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected from problems index" do
    sign_in_as("john", "hello")
    get problems_path
    assert_redirected_to list_main_path
  end

  test "admin can access problems index" do
    sign_in_as("admin", "admin")
    get problems_path
    assert_response :success
  end

  test "group editor can access problems index" do
    sign_in_as("mary", "mary")
    get problems_path
    assert_response :success
  end

  # --- Read actions ---

  test "admin can edit problem" do
    sign_in_as("admin", "admin")
    get edit_problem_path(problems(:prob_add))
    assert_response :success
  end

  test "admin can view problem stat" do
    sign_in_as("admin", "admin")
    get stat_problem_path(problems(:prob_add))
    assert_response :success
  end

  test "admin can destroy problem" do
    sign_in_as("admin", "admin")
    prob = problems(:prob_sub)
    assert_difference "Problem.count", -1 do
      delete problem_path(prob)
    end
  end

  test "admin can access manage page" do
    sign_in_as("admin", "admin")
    get manage_problems_path
    assert_response :success
  end
end
