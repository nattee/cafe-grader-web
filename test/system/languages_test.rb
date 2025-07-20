require "application_system_test_case"

class LanguagesTest < ApplicationSystemTestCase
  setup do
    @language = languages(:one)
  end

  test "visiting the index" do
    visit languages_url
    assert_selector "h1", text: "Languages"
  end

  test "should create language" do
    visit languages_url
    click_on "New language"

    click_on "Create Language"

    assert_text "Language was successfully created"
    click_on "Back"
  end

  test "should update Language" do
    visit language_url(@language)
    click_on "Edit this language", match: :first

    click_on "Update Language"

    assert_text "Language was successfully updated"
    click_on "Back"
  end

  test "should destroy Language" do
    visit language_url(@language)
    click_on "Destroy this language", match: :first

    assert_text "Language was successfully destroyed"
  end
end
