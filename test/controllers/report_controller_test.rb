require "test_helper"

# Covers the activity report (per-user submission summary).
# The older reports (max_score / submission / login) predate this file
# and are still untested — extend here when touching them.
class ReportControllerTest < ActionDispatch::IntegrationTest
  # all submission fixtures are submitted_at 2019-10-22
  RANGE = { use: "time", from_time: "2019-01-01 00:00", to_time: "2020-12-31 00:00" }.freeze

  def activity_params(extra = {})
    { sub_range: RANGE, probs: { use: "all" }, users: { use: "all" } }.merge(extra)
  end

  def query_rows(extra = {})
    post activity_query_report_path(format: :json), params: activity_params(extra)
    assert_response :success
    response.parsed_body["data"].index_by { |r| r["login"] }
  end

  # --- authorization ---

  test "unauthenticated cannot view activity report" do
    get activity_report_path
    assert_redirected_to login_main_path
  end

  test "regular user cannot view activity report" do
    sign_in_as("john", "hello")
    get activity_report_path
    assert_response :redirect
  end

  test "regular user cannot post activity_query" do
    sign_in_as("john", "hello")
    post activity_query_report_path(format: :json), params: activity_params
    assert_response :redirect
  end

  # --- aggregation ---

  test "admin can view activity report page" do
    sign_in_as("admin", "admin")
    get activity_report_path
    assert_response :success
  end

  test "activity_query aggregates submissions per user" do
    sign_in_as("admin", "admin")
    rows = query_rows

    assert_equal 2, rows["admin"]["sub_count"]   # add1_by_admin + sub1_by_admin
    assert_equal 2, rows["admin"]["prob_count"]
    assert_equal 0, rows["admin"]["solved_count"] # no fixture has points
    assert_equal 1, rows["john"]["sub_count"]
    assert_equal 2, rows["james"]["sub_count"]
    assert_not_nil rows["admin"]["first_sub"]
    assert_nil rows["mary"], "users with no submissions must be hidden by default"
  end

  test "solved counts 100-point submissions but excludes raw_sum-scored problems" do
    submissions(:add1_by_john).update_columns(points: 100)   # sum-scored -> solved
    submissions(:sub1_by_james).update_columns(points: 100)  # will become raw_sum -> excluded
    datasets(:ds_sub).update_columns(score_type: Dataset.score_types[:raw_sum])

    sign_in_as("admin", "admin")
    rows = query_rows

    assert_equal 1, rows["john"]["solved_count"]
    assert_equal 0, rows["james"]["solved_count"],
      "100 points on a raw_sum problem must not count as solved"
    assert_equal 2, rows["james"]["prob_count"], "raw_sum problems still count as tried"
  end

  test "time range excludes submissions outside it" do
    sign_in_as("admin", "admin")
    rows = query_rows(sub_range: { use: "time", from_time: "2030-01-01 00:00", to_time: "2030-12-31 00:00" })
    assert_empty rows
  end

  test "show_inactive appends zero rows for selected users" do
    sign_in_as("admin", "admin")
    rows = query_rows(show_inactive: "true")

    assert_not_nil rows["mary"]
    assert_equal 0, rows["mary"]["sub_count"]
    assert_nil rows["mary"]["first_sub"]
    assert_equal 2, rows["admin"]["sub_count"], "active rows unaffected by show_inactive"
  end

  # --- reporter scoping & empty-state feedback (group mode) ---
  #
  # group_a (enabled) holds prob_add (available) and prob_sub (unavailable).
  # reba is a plain reporter of group_a; mary is an editor. Reporters are gated
  # by availability, so the empty-state notice is a reporter concern (an editor
  # bypasses the flags and never hits it). The reports are group-scoped, so these
  # tests flip the grader into problem-group mode first.

  def enable_group_mode
    set_grader_config("system.use_problem_group", true)
    assert GraderConfiguration.use_problem_group?, "group mode must be on for these tests"
  end

  test "reporter whose problems are all hidden sees the empty-report notice" do
    enable_group_mode
    problems(:prob_add).update_columns(available: false)   # now BOTH group_a problems are unavailable

    sign_in_as("reba", "reba")
    get max_score_report_path
    assert_response :success   # gate is group-based, so he still reaches the screen

    # report scope is empty, but 2 problems exist in his group -> explained, not a silent blank
    assert_match(/Nothing to report yet/, response.body)
    assert_match(/2 problems/, response.body)
    assert_match(/hidden from reports/, response.body)
  end

  test "empty-report notice is suppressed when the reporter has reportable data" do
    enable_group_mode   # prob_add stays available -> reba can report on it

    sign_in_as("reba", "reba")
    get max_score_report_path
    assert_response :success
    assert_no_match(/Nothing to report yet/, response.body)
  end

  test "empty-report notice never shows for an admin" do
    enable_group_mode
    Problem.update_all(available: false)   # nothing reportable at all

    sign_in_as("admin", "admin")
    get max_score_report_path
    assert_response :success
    assert_no_match(/Nothing to report yet/, response.body)  # admin sees Problem.all, no hint
  end

  test "user-group filter is scoped to the reporter's groups, not all groups" do
    enable_group_mode

    sign_in_as("mary", "mary")
    get max_score_report_path
    assert_response :success

    options = css_select('select[name="users[group_ids]"] option').map { |o| o.text.strip }
    assert_includes options, "GroupA"
    refute_includes options, "GroupB", "a reporter must not see groups they cannot report on"
  end

  test "admin still sees every group in the user-group filter" do
    enable_group_mode

    sign_in_as("admin", "admin")
    get max_score_report_path
    assert_response :success

    options = css_select('select[name="users[group_ids]"] option').map { |o| o.text.strip }
    assert_includes options, "GroupA"
    assert_includes options, "GroupB"
  end

  test "an archived group an editor can still report on is flagged archived in the filter" do
    enable_group_mode
    groups(:group_a).update!(enabled: false)   # archive mary's (editor) group

    sign_in_as("mary", "mary")
    get max_score_report_path
    assert_response :success

    archived = css_select('select[name="users[group_ids]"] option[data-archived="true"]').map { |o| o.text.strip }
    assert_includes archived, "GroupA", "an editor's archived group must be marked archived in the dropdown"
  end

  test "a reporter of only an archived group is blocked from the report screen" do
    enable_group_mode
    groups(:group_a).update!(enabled: false)   # reba (reporter) now has no live report groups

    sign_in_as("reba", "reba")
    get max_score_report_path
    assert_response :redirect,
      "a reporter with no live report groups should be turned away at the gate, not shown an empty screen"
  end

  # --- role-aware scope help band ---

  test "scope help shows a reporter their live-courses-only line and courses" do
    sign_in_as("reba", "reba")
    get max_score_report_path
    assert_response :success
    assert_match(/Reporter/, response.body)
    assert_match(/live courses only/, response.body)
    assert_match(/GroupA/, response.body)
    assert_match(/Courses you report on/, response.body)   # the drawer breakdown
  end

  test "scope help tells an editor they have full access incl. archived" do
    sign_in_as("mary", "mary")
    get max_score_report_path
    assert_response :success
    assert_match(/Editor/, response.body)
    assert_match(/including archived courses/, response.body)
    assert_match(/Courses you edit/, response.body)
  end

  test "scope help tells an admin they see everything" do
    sign_in_as("admin", "admin")
    get max_score_report_path
    assert_response :success
    assert_match(/Admin/, response.body)
    assert_match(/no role limits apply/, response.body)
  end
end
