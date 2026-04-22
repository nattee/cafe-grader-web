require "test_helper"

class LanguagesControllerTest < ActionDispatch::IntegrationTest
  test "admin can access languages index" do
    sign_in_as("admin", "admin")
    get languages_url
    assert_response :success
  end

  test "admin can create language" do
    sign_in_as("admin", "admin")
    assert_difference("Language.count") do
      post languages_url, params: { language: { name: "swift", pretty_name: "Swift", ext: "swift", common_ext: "swift" } }
    end
  end

  test "admin can edit language" do
    sign_in_as("admin", "admin")
    get edit_language_url(languages(:Language_c))
    assert_response :success
  end

  test "admin can update language" do
    sign_in_as("admin", "admin")
    patch language_url(languages(:Language_c)), params: { language: { pretty_name: "C Language" } }
    assert_redirected_to language_url(languages(:Language_c))
  end

  test "admin can destroy language" do
    sign_in_as("admin", "admin")
    # Create a new one to destroy (don't destroy ones with submissions)
    lang = Language.create!(name: "temp", pretty_name: "Temp", ext: "tmp", common_ext: "tmp")
    assert_difference("Language.count", -1) do
      delete language_url(lang)
    end
  end
end
