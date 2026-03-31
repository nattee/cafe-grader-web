require "test_helper"

class UserAdminControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get user_admin_index_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected" do
    sign_in_as("john", "hello")
    get user_admin_index_path
    assert_redirected_to list_main_path
  end

  test "admin can access user admin index" do
    sign_in_as("admin", "admin")
    get user_admin_index_path
    assert_response :success
  end

  # --- CRUD ---

  test "admin can access new user form" do
    sign_in_as("admin", "admin")
    get new_user_admin_path
    assert_response :success
  end

  test "admin can create user" do
    sign_in_as("admin", "admin")
    assert_difference "User.count" do
      post user_admin_index_path, params: {
        user: {
          login: "newuser",
          full_name: "New User",
          password: "secret",
          password_confirmation: "secret"
        }
      }
    end
  end

  test "admin can edit user" do
    sign_in_as("admin", "admin")
    get edit_user_admin_path(users(:john))
    assert_response :success
  end

  test "admin can update user" do
    sign_in_as("admin", "admin")
    patch user_admin_path(users(:john)), params: {
      user: { full_name: "Updated John" }
    }
    assert_equal "Updated John", users(:john).reload.full_name
  end

  test "admin can destroy user" do
    sign_in_as("admin", "admin")
    user = users(:disabled_user)
    assert_difference "User.count", -1 do
      delete user_admin_path(user)
    end
  end

  test "admin can toggle activate" do
    sign_in_as("admin", "admin")
    user = users(:disabled_user)
    assert_not user.activated?
    get toggle_activate_user_admin_path(user)
    assert user.reload.activated?
  end

  test "create from list creates users" do
    sign_in_as("admin", "admin")
    post create_from_list_user_admin_index_path, params: {
      user_list: "bulkuser1,Bulk User One,pass1\nbulkuser2,Bulk User Two,pass2"
    }
    assert User.find_by_login("bulkuser1")
    assert User.find_by_login("bulkuser2")
  end
end
