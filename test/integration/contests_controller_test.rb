require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  # --- Authorization ---

  test "unauthenticated user is redirected" do
    get contests_path
    assert_redirected_to login_main_path
  end

  test "normal user is redirected from contests index" do
    sign_in_as("john", "hello")
    get contests_path
    assert_redirected_to list_main_path
  end

  test "admin can access contests index" do
    sign_in_as("admin", "admin")
    get contests_path
    assert_response :success
  end

  test "group editor can access contests index" do
    sign_in_as("mary", "mary")
    get contests_path
    assert_response :success
  end

  # --- CRUD ---

  test "admin can create contest" do
    sign_in_as("admin", "admin")
    assert_difference "Contest.count" do
      post contests_path, params: {
        contest: {
          name: "new_contest",
          enabled: true
        }
      }
    end
  end

  test "admin can view contest" do
    sign_in_as("admin", "admin")
    get contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can edit contest" do
    sign_in_as("admin", "admin")
    get edit_contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can destroy contest" do
    sign_in_as("admin", "admin")
    contest = contests(:contest_c)
    assert_difference "Contest.count", -1 do
      delete contest_path(contest)
    end
  end

  # --- Cross-permission ---

  test "group editor (mary) can view their contest" do
    sign_in_as("mary", "mary")
    get contest_path(contests(:contest_a))
    assert_response :success
  end

  test "group editor (mary) cannot view a contest they don't own" do
    sign_in_as("mary", "mary")
    get contest_path(contests(:contest_b))
    assert_response :redirect
  end

  # --- Member actions ---

  test "admin can clone a contest" do
    sign_in_as("admin", "admin")
    assert_difference "Contest.count", +1 do
      get clone_contest_path(contests(:contest_a))
    end
  end

  test "admin can view contest score report" do
    sign_in_as("admin", "admin")
    get view_contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can query contest scores as JSON" do
    sign_in_as("admin", "admin")
    post view_query_contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can query contest users as JSON" do
    sign_in_as("admin", "admin")
    post show_users_query_contest_path(contests(:contest_a))
    assert_response :success
  end

  test "admin can query contest problems as JSON" do
    sign_in_as("admin", "admin")
    post show_problems_query_contest_path(contests(:contest_a))
    assert_response :success
  end

  # --- Collection actions ---

  test "admin can change system mode" do
    sign_in_as("admin", "admin")
    post set_system_mode_contests_path, params: { mode: "standard" }
    assert_response :redirect
  end

  test "non-admin cannot change system mode" do
    set_grader_config("system.mode", "standard")
    sign_in_as("mary", "mary")   # a group editor — could flip the site's mode before B4
    post set_system_mode_contests_path, params: { mode: "contest" }
    assert_response :redirect
    assert_equal "standard", GraderConfiguration[GraderConfiguration::SYSTEM_MODE_CONF_KEY]
  ensure
    set_grader_config("system.mode", "standard")
  end

  test "user_check_in returns JSON heartbeat" do
    sign_in_as("james", "morning")
    post user_check_in_contests_path
    assert_response :success
  end

  # --- finish_open_vivas (the "Finish open vivas" button) ---

  def viva_language
    Language.find_or_create_by!(name: "viva") { |l| l.pretty_name = "Viva Exam" }
  end

  def add_viva_to_contest_a
    ContestProblem.create!(contest: contests(:contest_a), problem: problems(:prob_viva), number: 3, enabled: true)
  end

  def open_viva_in_contest_a(answered: true)
    Submission.create!(user: users(:james), problem: problems(:prob_viva), language: viva_language,
                       status: :submitted, submitted_at: Time.zone.now).tap do |sub|
      sub.viva_turns.create!(role: :assistant, status: :ok, content: 'hello')
      sub.viva_turns.create!(role: :student, status: :ok, content: 'answer') if answered
    end
  end

  def finish_open_vivas_audit_rows
    AuditLog.where(auditable_type: 'Contest', auditable_id: contests(:contest_a).id, action: 'finish_open_vivas')
  end

  test "contest page shows the Finish open vivas button only when the contest has a viva problem" do
    sign_in_as("admin", "admin")
    get contest_path(contests(:contest_a))
    assert_response :success
    assert_no_match(/Finish open vivas/, response.body)

    add_viva_to_contest_a
    open_viva_in_contest_a
    get contest_path(contests(:contest_a))
    assert_response :success
    assert_match(/Finish open vivas/, response.body)
    assert_match(/Finish 1 open viva session\?/, response.body)
  end

  test "finish_open_vivas grades answered sessions, archives greeting-only ones, toasts and audits the counts" do
    add_viva_to_contest_a
    answered = open_viva_in_contest_a(answered: true)
    peek     = open_viva_in_contest_a(answered: false)
    sign_in_as("admin", "admin")
    assert_difference -> { finish_open_vivas_audit_rows.count }, 1 do
      assert_enqueued_with(job: Llm::VivaGradeAssistJob) do
        post finish_open_vivas_contest_path(contests(:contest_a)), as: :turbo_stream
      end
    end
    assert_response :success
    assert_match(/Sent 1 session to grading, archived 1 greeting-only session\./, response.body)
    assert_match(/target="open-viva-count"/, response.body, "response must refresh the button's open-count badge")
    assert_predicate answered.reload, :evaluating?
    assert peek.reload.viva_archived_at.present?
    log = finish_open_vivas_audit_rows.last
    assert_equal [nil, 1], log.object_changes['graded_count']
    assert_equal [nil, 1], log.object_changes['archived_count']
    assert_equal [nil, 0], log.object_changes['skipped_count']
  end

  test "finish_open_vivas with nothing open toasts and writes no audit row" do
    add_viva_to_contest_a
    sign_in_as("admin", "admin")
    assert_no_difference -> { AuditLog.count } do
      post finish_open_vivas_contest_path(contests(:contest_a)), as: :turbo_stream
    end
    assert_response :success
    assert_match(/No open viva sessions\./, response.body)
  end

  test "contest editor (mary) can finish open vivas of their own contest" do
    add_viva_to_contest_a
    sign_in_as("mary", "mary")
    post finish_open_vivas_contest_path(contests(:contest_a)), as: :turbo_stream
    assert_response :success
  end

  test "contest editor (mary) cannot finish open vivas of a contest they don't manage" do
    sign_in_as("mary", "mary")
    post finish_open_vivas_contest_path(contests(:contest_b)), as: :turbo_stream
    assert_response :redirect
  end

  test "normal user cannot finish open vivas" do
    sign_in_as("john", "hello")
    post finish_open_vivas_contest_path(contests(:contest_a)), as: :turbo_stream
    assert_response :redirect
  end

  # --- viva grading status line (next to "Finish open vivas") ---

  def viva_session_in_contest_a(status:)
    Submission.create!(user: users(:james), problem: problems(:prob_viva), language: viva_language,
                       status: status, submitted_at: Time.zone.now)
  end

  test "contest page shows All vivas graded when nothing is waiting, with the refresh timer off" do
    add_viva_to_contest_a
    sign_in_as("admin", "admin")
    get contest_path(contests(:contest_a))
    assert_response :success
    assert_select 'turbo-frame#viva-status', 1
    assert_select 'turbo-frame#viva-status .badge', text: 'All vivas graded'
    assert_select 'turbo-frame#viva-status [data-controller=refresh][data-refresh-delay-value="-1"]', 1
  end

  test "viva_status shows the grading and error counts and keeps refreshing while grading" do
    add_viva_to_contest_a
    viva_session_in_contest_a(status: :evaluating)
    viva_session_in_contest_a(status: :evaluating)
    viva_session_in_contest_a(status: :grader_error)
    sign_in_as("admin", "admin")
    get viva_status_contest_path(contests(:contest_a))
    assert_response :success
    assert_select 'turbo-frame#viva-status .badge', text: 'Grading: 2 in progress'
    assert_select 'turbo-frame#viva-status .badge', text: '1 grader error'
    assert_select 'turbo-frame#viva-status [data-refresh-delay-value="10000"]', 1
    assert_select "turbo-frame#viva-status a[href=?][data-refresh-target=refreshLink]", viva_status_contest_path(contests(:contest_a))
  end

  test "viva_status stops refreshing when only grader errors are left" do
    add_viva_to_contest_a
    viva_session_in_contest_a(status: :grader_error)
    sign_in_as("admin", "admin")
    get viva_status_contest_path(contests(:contest_a))
    assert_select 'turbo-frame#viva-status .badge', text: '1 grader error'
    assert_select 'turbo-frame#viva-status [data-refresh-delay-value="-1"]', 1
  end

  test "contest page has no viva status line when the contest has no viva problem" do
    sign_in_as("admin", "admin")
    get contest_path(contests(:contest_a))
    assert_select 'turbo-frame#viva-status', 0
  end

  test "a student cannot read the viva status" do
    add_viva_to_contest_a
    sign_in_as("james", "morning")
    get viva_status_contest_path(contests(:contest_a))
    assert_response :redirect
  end
end
