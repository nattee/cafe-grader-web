require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get contests_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected from contests index" do
    sign_in_as("john", "hello")
    get contests_path
    assert_redirected_to list_main_path
  end

  test "admin can access contests index" do
    sign_in_as("admin", "admin")
    get contests_path
    assert_response :success
  end

  test "group editor can access contests index" do
    sign_in_as("mary", "mary")
    get contests_path
    assert_response :success
  end

  # --- CRUD ---

  test "admin can create contest" do
    sign_in_as("admin", "admin")
    assert_difference "Contest.count" do
      post contests_path, params: {
        contest: {
          name: "new_contest",
          enabled: true
        }
      }
    end
  end

  test "admin can view contest" do
    sign_in_as("admin", "admin")
    get contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can edit contest" do
    sign_in_as("admin", "admin")
    get edit_contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can destroy contest" do
    sign_in_as("admin", "admin")
    contest = contests(:contest_c)
    assert_difference "Contest.count", -1 do
      delete contest_path(contest)
    end
  end
end
