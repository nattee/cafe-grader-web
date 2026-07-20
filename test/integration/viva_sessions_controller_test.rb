require "test_helper"

class VivaSessionsControllerTest < ActionDispatch::IntegrationTest
  # `viva_sessions#start` requires both:
  #   - a problem with mode=:viva_exam
  #   - a Language with name='viva' (seeded; not in fixtures)
  # We test the failure paths plus the basic auth boundary.

  setup do
    @owner_sub = submissions(:add1_by_john)         # owned by `john`
    @other_sub = submissions(:add1_by_admin)        # owned by admin (john not the owner)
  end

  # --- Authorization on show ---

  test "unauthenticated cannot view viva session" do
    get viva_submission_path(@owner_sub)
    assert_redirected_to login_main_path
  end

  test "owner can view their viva session" do
    sign_in_as("john", "hello")
    get viva_submission_path(@owner_sub)
    # show has no explicit owner check — the view just renders viva_turns.
    # That's questionable, but it's the current behavior; we document it.
    assert_response :success
  end

  test "admin can view any viva session" do
    sign_in_as("admin", "admin")
    get viva_submission_path(@other_sub)
    assert_response :success
  end

  test "student owner sees system turns (jailbreak warnings, practice notices)" do
    # System turns carry content students MUST see (e.g. jailbreak-attempt
    # warnings, practice-mode notices) — they must not be admin-gated.
    sign_in_as("john", "hello")
    @owner_sub.viva_turns.create!(role: :system, status: :ok, content: "VISIBILITY-PROBE-WARNING")
    get viva_submission_path(@owner_sub)
    assert_response :success
    assert_includes @response.body, "VISIBILITY-PROBE-WARNING"
  end

  # --- answer enforces ownership ---

  test "non-owner cannot answer in another user's viva session" do
    sign_in_as("john", "hello")
    post viva_answer_submission_path(@other_sub), params: { content: "hi" }
    assert_redirected_to list_main_path
  end

  test "admin cannot answer in another user's viva session" do
    # Admins can VIEW other students' viva sessions (assert above) but must
    # not be able to POST on their behalf — that would corrupt transcript
    # ownership. Before the fix the controller allowed any admin to answer
    # in any session via `|| @current_user.admin?`; the new policy is
    # owner-only, regardless of admin role.
    sign_in_as("admin", "admin")
    assert_no_difference "VivaTurn.count" do
      post viva_answer_submission_path(@owner_sub), params: { content: "hi" }
    end
    assert_redirected_to list_main_path
  end

  test "admin can still answer in their own viva session" do
    # Regression guard: removing the admin-bypass shouldn't accidentally
    # block admin from posting to a viva session they themselves own.
    # Auth passes; the request then redirects out via the empty-content
    # validation, which is the same path the owner case takes.
    sign_in_as("admin", "admin")
    post viva_answer_submission_path(@other_sub), params: { content: "   " }
    assert_response :redirect
    refute_equal list_main_path, @response.headers["Location"],
      "should not be redirected to list (auth failure); should fall through to validation redirect"
  end

  test "owner gets validation error when answering with empty content" do
    sign_in_as("john", "hello")
    post viva_answer_submission_path(@owner_sub), params: { content: "   " }
    assert_response :redirect # redirect to viva path with alert
  end

  test "answer at hard cap force-finishes and enqueues grading" do
    sign_in_as("john", "hello")
    @owner_sub.problem.update!(viva_hard_cap: 2)
    2.times { |i| @owner_sub.viva_turns.create!(role: :student, status: :ok, content: "a#{i}") }
    assert_enqueued_with(job: Llm::VivaGradeAssistJob) do
      post viva_answer_submission_path(@owner_sub), params: { content: "one more" }
    end
    assert_redirected_to viva_submission_path(@owner_sub)
    assert_equal "evaluating", @owner_sub.reload.status
    assert_equal 2, @owner_sub.viva_turns.where(role: :student).count,
      "the over-cap answer must not be recorded"
  end

  # --- start failure paths ---

  test "start redirects when problem is not a viva exam" do
    sign_in_as("admin", "admin")
    # prob_add has mode default (general), not viva_exam
    post viva_start_problem_path(problems(:prob_add))
    assert_redirected_to list_main_path
  end

  # --- retry_turn ---

  # Helper: build a :error assistant turn so we have a target to retry.
  def make_failed_turn(submission)
    submission.viva_turns.create!(
      role:    :assistant,
      status:  :error,
      content: "boom"
    )
  end

  test "owner can retry a failed turn on their own viva" do
    sign_in_as("john", "hello")
    turn = make_failed_turn(@owner_sub)
    assert_enqueued_with(job: Llm::VivaTurnAssistJob) do
      post viva_retry_turn_submission_path(@owner_sub, turn_id: turn.id)
    end
    assert_redirected_to viva_submission_path(@owner_sub)
    turn.reload
    assert_predicate turn, :processing?, "turn should be reset to :processing"
    assert_nil turn.content, "content should be cleared so the spinner shows again"
  end

  test "admin can retry a failed turn on someone else's viva" do
    sign_in_as("admin", "admin")
    turn = make_failed_turn(@owner_sub)  # john's session, admin retries
    assert_enqueued_with(job: Llm::VivaTurnAssistJob) do
      post viva_retry_turn_submission_path(@owner_sub, turn_id: turn.id)
    end
    assert_redirected_to viva_submission_path(@owner_sub)
    turn.reload
    assert_predicate turn, :processing?
  end

  test "unrelated user cannot retry someone else's viva turn" do
    # `mary` is neither the owner (john) nor an admin.
    sign_in_as("mary", "mary")
    turn = make_failed_turn(@owner_sub)
    assert_no_enqueued_jobs(only: Llm::VivaTurnAssistJob) do
      post viva_retry_turn_submission_path(@owner_sub, turn_id: turn.id)
    end
    turn.reload
    assert_predicate turn, :error?, "turn must NOT have been reset"
  end

  test "retry refuses when turn is not in :error state" do
    sign_in_as("john", "hello")
    fresh = @owner_sub.viva_turns.create!(role: :assistant, status: :processing, content: nil)
    assert_no_enqueued_jobs(only: Llm::VivaTurnAssistJob) do
      post viva_retry_turn_submission_path(@owner_sub, turn_id: fresh.id)
    end
    fresh.reload
    assert_predicate fresh, :processing?, "in-flight turn should not be reset"
  end

  test "retry refuses when target turn is a system or student turn" do
    sign_in_as("john", "hello")
    student_turn = @owner_sub.viva_turns.create!(role: :student, status: :ok, content: "answer")
    # Hack the status to error to bypass the status guard and isolate the role guard.
    VivaTurn.where(id: student_turn.id).update_all(status: 2) # :error
    assert_no_enqueued_jobs(only: Llm::VivaTurnAssistJob) do
      post viva_retry_turn_submission_path(@owner_sub, turn_id: student_turn.id)
    end
  end

  # --- answer below hard cap: happy path (Task 5 review follow-up) ---

  test "answer below hard cap records a student turn and enqueues the assist job" do
    sign_in_as("john", "hello")
    @owner_sub.problem.update!(viva_hard_cap: 15)
    assert @owner_sub.viva_turns.where(role: :student).count < @owner_sub.problem.viva_hard_cap,
      "fixture must start below the hard cap for this to be a meaningful test"

    assert_enqueued_with(job: Llm::VivaTurnAssistJob) do
      assert_difference "@owner_sub.viva_turns.where(role: :student).count", 1 do
        post viva_answer_submission_path(@owner_sub), params: { content: "my answer" }
      end
    end
    assert_redirected_to viva_submission_path(@owner_sub)
    assert_equal "submitted", @owner_sub.reload.status,
      "below the hard cap the interview keeps going — status must not flip to evaluating"
    placeholder = @owner_sub.viva_turns.order(:id).last
    assert_equal "assistant", placeholder.role
    assert_predicate placeholder, :processing?
  end

  # --- restart (D2 practice self-service retake) ---

  # `viva` Language isn't in fixtures (see the file-level comment above) —
  # find_or_create_by! so this works whether or not another test already
  # seeded it within this run.
  def viva_language
    Language.find_or_create_by!(name: 'viva') { |l| l.pretty_name = 'Viva Exam' }
  end

  test "owner can restart a practice viva; exam mode refuses" do
    sign_in_as("john", "hello")
    @owner_sub.problem.update!(viva_mode: :practice)
    post viva_restart_submission_path(@owner_sub)
    assert @owner_sub.reload.viva_archived_at.present?

    @owner_sub.problem.update!(viva_mode: :exam)
    sub2 = Submission.create!(user: @owner_sub.user, problem: @owner_sub.problem,
                              language: viva_language, status: :submitted,
                              submitted_at: Time.zone.now)
    post viva_restart_submission_path(sub2)
    assert_nil sub2.reload.viva_archived_at
  end

  test "non-owner cannot restart another user's viva" do
    sign_in_as("admin", "admin")
    @owner_sub.problem.update!(viva_mode: :practice)
    post viva_restart_submission_path(@owner_sub)
    assert_nil @owner_sub.reload.viva_archived_at
  end

  test "practice start is rate-limited per day" do
    # Exercised through the real #start endpoint, so the fixture problem
    # must actually pass every guard ahead of the rate limit: viva_exam
    # compilation_type, submit authorization, a seeded 'viva' Language,
    # and a viva_prompt satisfying Problem::VIVA_PROMPT_REQUIRED_SECTIONS.
    # prob_add (used elsewhere in this file) is a plain problem and would
    # be refused before ever reaching the rate-limit check, so we use
    # prob_viva (already compilation_type: viva_exam, available: true).
    sign_in_as("john", "hello")
    problem = problems(:prob_viva)
    problem.update!(viva_mode: :practice, viva_prompt: "# Rubric\nBe fair.")
    user = users(:john)
    3.times do
      Submission.create!(user: user, problem: problem, language: viva_language,
                         status: :submitted, submitted_at: Time.zone.now, viva_archived_at: Time.zone.now)
    end
    post viva_start_problem_path(problem)   # 4th today -> refused
    assert_redirected_to list_main_path
    assert_match(/Daily practice limit/, flash[:alert])
    assert_equal 3, problem.submissions.where(user: user).count
  end
end
