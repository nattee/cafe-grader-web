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

  test "add multiple users" do
    login 'admin', 'admin'
    within 'header' do
      click_on 'Manage'
      click_on 'Users', match: :first
    end

    click_on 'New list of users', match: :first
    find(:css, 'textarea').fill_in with:"abc1,Boaty McBoatface,abcdef,alias1,remark1,\nabc2,Boaty2 McSecond,acbdef123,aias2,remark2"
    click_on 'Create following users'

    assert_text('remark1')
    assert_text('remark2')
  end

  test "grant admin right" do
    login 'admin', 'admin'
    within 'header' do
      click_on 'Manage'
      click_on 'Users', match: :first
    end

    click_on "View administrator"
    fill_in 'login', with: 'john'
    click_on "Grant"

    visit logout_main_path
    login 'john','hello'
    within 'header' do
      click_on 'Manage'
      click_on 'Problem', match: :first
    end
    assert_text "Turn off all problems"
  end

  test "try using admin from normal user" do
    login 'admin','admin'
    visit  bulk_manage_user_admin_index_path
    assert_current_path bulk_manage_user_admin_index_path
    visit logout_main_path

    login 'jack','morning'
    visit  bulk_manage_user_admin_index_path
    assert_text 'You are not authorized'
    assert_current_path login_main_path

    login 'james','morning'
    visit  new_list_user_admin_index_path
    assert_text 'You are not authorized'
    assert_current_path login_main_path
  end

  test "login then change password" do
    newpassword = '1234asdf'
    login 'john', 'hello'
    visit profile_users_path

    fill_in 'password', with: newpassword
    fill_in 'password_confirmation', with: newpassword

    click_on 'Edit'

    visit logout_main_path
    login 'john', 'hello'
    assert_text 'Wrong password'

    login 'john', newpassword
    assert_text "MAIN"
    assert_text "Submission"
  end

  def login(username,password)
    visit root_path
    fill_in "Login", with: username
    fill_in "Password", with: password
    click_on "Login"
  end
end
