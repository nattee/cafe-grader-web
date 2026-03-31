require "test_helper"

class MainControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to login" do
    get list_main_path
    assert_redirected_to login_main_path
  end

  test "authenticated user can see list page" do
    sign_in_as("john", "hello")
    get list_main_path
    assert_response :success
  end

  test "login page loads successfully" do
    get root_path
    assert_response :success
  end

  test "logout redirects to root" do
    sign_in_as("john", "hello")
    get logout_main_path
    assert_response :redirect
  end

  test "admin can see list page" do
    sign_in_as("admin", "admin")
    get list_main_path
    assert_response :success
  end

  test "submit creates submission via editor" do
    sign_in_as("admin", "admin")
    prob = problems(:prob_add)
    lang = languages(:Language_c)
    assert_difference "Submission.count" do
      post submit_main_path, params: {
        submission: { problem_id: prob.id },
        language_id: lang.id,
        editor_text: "int main() { return 0; }"
      }
    end
  end

  test "help page loads" do
    sign_in_as("john", "hello")
    get help_main_path
    assert_response :success
  end
end
