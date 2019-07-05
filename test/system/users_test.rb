require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  # test "visiting the index" do
  #   visit users_url
  #
  #   assert_selector "h1", text: "User"
  # end

  test "add new user and edit" do
    login('admin','admin')
    within 'header' do
      click_on 'Manage'
      click_on 'Users', match: :first
    end

    assert_text "Users"
    assert_text "New user"

    click_on "New user", match: :first
    fill_in 'Login', with: 'test1'
    fill_in 'Full name', with: 'test1 McTestface'
    fill_in 'e-mail', with: 'a@a.com'
    fill_in 'Password', with: 'abcdef'
    fill_in 'Password confirmation', with: 'abcdef'

    click_on 'Create'

    assert_text 'User was successfully created'
    assert_text 'a@a.com'
    assert_text 'test1 McTestface'

    within('tr', text: 'McTestface') do
      click_on 'Edit'
    end

    fill_in 'Alias', with: 'hahaha'
    fill_in 'Remark', with: 'section 2'
    click_on 'Update User'

    assert_text 'section 2'
  end

  def login(username,password)
    visit root_path
    fill_in "Login", with: username
    fill_in "Password", with: password
    click_on "Login"
  end
end
