require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  test "admin can access tags index" do
    sign_in_as("admin", "admin")
    get tags_path
    assert_response :success
  end

  test "admin can create tag" do
    sign_in_as("admin", "admin")
    assert_difference("Tag.count") do
      post tags_path, params: { tag: { name: "new_tag", description: "A new tag", public: true } }
    end
  end

  test "admin can edit tag" do
    sign_in_as("admin", "admin")
    get edit_tag_path(tags(:tag_easy))
    assert_response :success
  end

  test "admin can destroy tag" do
    sign_in_as("admin", "admin")
    assert_difference("Tag.count", -1) do
      delete tag_path(tags(:tag_hard))
    end
  end
end
