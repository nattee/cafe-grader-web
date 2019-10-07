require "application_system_test_case"

class SubmissionsTest < ApplicationSystemTestCase
  # test "visiting the index" do
  #   visit users_url
  #
  #   assert_selector "h1", text: "User"
  # end

  test "add new submission" do
    #admin can add new submission regardless of availability of the problem
    login('admin','admin')
    visit direct_edit_problem_submissions_path(problems(:prob_sub))
    assert_text 'Live submit'
    find('.ace_text-input',visible: false).set "test code (will cause compilation error)"
    click_on 'Submit'
    page.accept_confirm
    assert_text 'less than a minute ago'
    visit logout_main_path

    #normal user can submit available problem
    login('john','hello')
    visit direct_edit_problem_submissions_path(problems(:prob_add))
    assert_text 'Live submit'
    find('.ace_text-input',visible: false).set "test code (will cause compilation error)"
    click_on 'Submit'
    page.accept_confirm
    assert_text 'less than a minute ago'
    visit logout_main_path

    #but not unavailable problem
    login('john','hello')
    visit direct_edit_problem_submissions_path(problems(:prob_sub))
    assert_text 'You are not authorized'
  end


  def login(username,password)
    visit root_path
    fill_in "Login", with: username
    fill_in "Password", with: password
    click_on "Login"
  end
end
