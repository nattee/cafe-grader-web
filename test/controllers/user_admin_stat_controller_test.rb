require "test_helper"

# /user_admin/:id/stat — the per-user statistics page, and its per-contest variant.
class UserAdminStatControllerTest < ActionDispatch::IntegrationTest
  def assist(sub, model, user:, **attrs)
    Comment.create!({commentable: sub, user: user, kind: 'llm_assist', status: 'ok', llm_model: model, cost: 10,
                     title: "Assistance by #{model}"}.merge(attrs))
  end

  test "AI Assist total and the by-model table count requests on the user's submissions, whoever pressed Get" do
    john = users(:john)
    assist(submissions(:add1_by_john), 'm1', user: john)
    assist(submissions(:add1_by_john), 'm2', user: users(:admin), cost: 0, llm_cost: 0.3)   # admin asked; free for john
    assist(submissions(:add1_by_james), 'm1', user: users(:james))                         # someone else's
    sign_in_as("admin", "admin")
    get stat_user_admin_path(john)
    assert_response :success
    assert_select ".row", text: /AI Assist\s+2\s*$/m
    assert_select ".llm-usage-table tbody tr", count: 2
    assert_select ".llm-usage-table tbody tr td code", text: "m1"
    assert_select ".llm-usage-table tbody tr td code", text: "m2"
    assert_select ".llm-usage-table tbody tr td", text: "$0.30"
    assert_select ".llm-usage-table tbody tr td", text: "—", minimum: 1   # m1 has no dollar figure
  end

  test "no table when the user never asked" do
    sign_in_as("admin", "admin")
    get stat_user_admin_path(users(:john))
    assert_response :success
    assert_select ".llm-usage-table", count: 0
    assert_select ".row", text: /AI Assist\s+0\s*$/m
  end

  test "the contest variant keeps only requests made inside the contest window" do
    james   = users(:james)
    contest = contests(:contest_a)                       # 1 hour ago → 3 hours from now; james is a member
    assist(submissions(:add1_by_james), 'm1', user: james, created_at: Time.zone.now)
    assist(submissions(:add1_by_james), 'm1', user: james, created_at: 2.days.ago)
    sign_in_as("admin", "admin")
    get stat_contest_user_admin_path(james, contest_id: contest.id)
    assert_response :success
    assert_select ".llm-usage-table tbody tr", count: 1
    assert_select ".llm-usage-table tbody tr td", text: "1"
    assert_select ".row", text: /AI Assist\s+1\s*$/m
  end
end
