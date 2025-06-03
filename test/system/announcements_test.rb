require "application_system_test_case"

class AnnouncementsTest < ApplicationSystemTestCase
  test "add new announcement" do
    visit root_path
    fill_in "Login", with: "admin"
    fill_in "Password", with: "admin"
    click_on "Login"

    assert_text "MAIN"
    assert_text "Submission"

    within :css, 'header' do
      click_on "Manage"
      click_on "Announcements"
    end
    assert_text "+ Add announcement"

    click_on "Add announcement", match: :first

    fill_in 'Title', with: 'test'
    fill_in 'Body', with: 'test body 12345'
    check 'Published'

    click_on 'Create'

    visit list_main_path

    assert_text "test body 12345"

  end
  # test "visiting the index" do
  #   visit announcements_url
  #
  #   assert_selector "h1", text: "Announcement"
  # end
end
