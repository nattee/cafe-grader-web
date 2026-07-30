# test/controllers/shadow_exclusion_controller_test.rb
require 'test_helper'

class ShadowExclusionControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original = submissions(:add1_by_john)
    @original.update_columns(status: Submission.statuses[:done], points: 40)
    @shadow = Submission.new(user: @original.user, problem: @original.problem,
                             language: @original.language, submitted_at: Time.zone.now,
                             source: "int main(){}", repaired_from_id: @original.id)
    @shadow.save!(validate: false)
    @shadow.update_columns(points: 100, status: Submission.statuses[:done])
  end

  test "student submission list omits shadows" do
    sign_in_as('john', 'hello')
    get submissions_path(problem_id: @original.problem_id)
    assert_response :success
    assert_match "##{@original.id}", response.body
    assert_no_match "##{@shadow.id}", response.body
  end

  test "student cannot open a shadow by id" do
    sign_in_as('john', 'hello')
    get submission_path(@shadow)
    assert_response :redirect
  end

  test "admin can open a shadow" do
    sign_in_as('admin', 'admin')
    get submission_path(@shadow)
    assert_response :success
  end
end
