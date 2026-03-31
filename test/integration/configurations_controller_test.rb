require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get grader_configuration_index_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected" do
    sign_in_as("john", "hello")
    get grader_configuration_index_path
    assert_redirected_to list_main_path
  end

  test "admin can access index" do
    sign_in_as("admin", "admin")
    get grader_configuration_index_path
    assert_response :success
  end

  # --- Actions ---

  test "admin can update configuration" do
    sign_in_as("admin", "admin")
    config = GraderConfiguration.find_by(key: "ui.front.title")
    patch grader_configuration_path(config), params: {
      grader_configuration: { value: "New Title" }
    }
    assert_equal "New Title", config.reload.value
  end

  test "admin can toggle boolean configuration" do
    sign_in_as("admin", "admin")
    config = GraderConfiguration.find_by(key: "system.single_user_mode")
    patch toggle_grader_configuration_path(config)
    assert_equal "true", config.reload.value
  end

  test "admin can edit configuration" do
    sign_in_as("admin", "admin")
    config = GraderConfiguration.find_by(key: "ui.front.title")
    get edit_grader_configuration_path(config)
    assert_response :success
  end
end
