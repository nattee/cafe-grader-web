require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected" do
    get groups_path
    assert_redirected_to login_main_path
  end

  test "admin can access groups index" do
    sign_in_as("admin", "admin")
    get groups_path
    assert_response :success
  end

  test "admin can create group" do
    sign_in_as("admin", "admin")
    assert_difference("Group.count") do
      post groups_path, params: { group: { name: "NewGroup", description: "Test" } }
    end
  end

  test "admin can view group" do
    sign_in_as("admin", "admin")
    get group_path(groups(:group_a))
    assert_response :success
  end

  test "admin can destroy group" do
    sign_in_as("admin", "admin")
    assert_difference("Group.count", -1) do
      delete group_path(groups(:group_b))
    end
  end
end
