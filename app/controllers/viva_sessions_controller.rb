class VivaSessionsController < ApplicationController
  before_action :check_valid_login
  before_action :set_problem, only: %i[start]
  before_action :set_submission, only: %i[show answer refresh retry_turn restart]
  # #answer/#retry_turn/#restart already enforce their own (stricter, owner-
  # or-admin) checks below — this gate is only for the read paths, which
  # previously had no authorization beyond being logged in at all. Reuses
  # the platform's existing submission-view predicate rather than
  # duplicating its admin/reporter/owner/config logic here.
  before_action :authorize_viva_view, only: %i[show refresh]

  # #show's "Viva Info" card reads this to render "N of L starts left today"
  # for practice-mode problems.
  helper_method :practice_daily_start_limit

  VIVA_LANGUAGE_NAME = 'viva'.freeze

  # Design D2: practice-mode students may start at most this many sessions
  # per problem per day (archived ones count — that's the point).
  #
  # Runtime-configurable via GraderConfiguration['viva.practice_daily_start_limit']
  # (see db/seeds.rb for the seeded default/description). DAILY_START_LIMIT_FALLBACK
  # is used only when that key is missing, blank, or non-positive — a
  # misconfigured/blank config must fall back to a safe limit, not open
  # unlimited starts. Read through #practice_daily_start_limit below.
  PRACTICE_DAILY_START_LIMIT_CONF_KEY = 'viva.practice_daily_start_limit'.freeze
  DAILY_START_LIMIT_FALLBACK = 3

  # POST /problems/:problem_id/viva/start
  def start
    unless @problem.viva_exam?
      redirect_to list_main_path, alert: 'This problem is not a viva exam.' and return
    end

    unless @current_user.problems_for_action(:submit).where(id: @problem.id).any?
      redirect_to list_main_path, alert: 'Authorization error: you have no right to start a viva for this problem.' and return
    end

    viva_lang = Language.find_by(name: VIVA_LANGUAGE_NAME)
    unless viva_lang
      redirect_to list_main_path, alert: 'Viva language is not seeded. Run Language.seed.' and return
    end

    setup_errors = @problem.viva_setup_errors
    if setup_errors.any?
      redirect_to list_main_path,
                  alert: "Cannot start viva for '#{@problem.name}' — problem setup is incomplete: #{setup_errors.join('; ')}"
      return
    end

    # Defensive: if the user already has an active (non-archived) viva
    # submission for this problem, the Start Viva button shouldn't be
    # visible — but a stale browser tab or a direct curl POST could land
    # here anyway. Refuse with a clear flash.
    if @problem.submissions.where(user: @current_user, viva_archived_at: nil).exists?
      redirect_to list_main_path,
                  alert: "You already have an active viva session for '#{@problem.name}'. An admin can archive it from the viva page if you need to retake."
      return
    end

    if @problem.viva_mode_practice? && !@current_user.admin? &&
       @problem.submissions.where(user: @current_user)
                .where('submitted_at >= ?', Time.zone.now.beginning_of_day).count >= practice_daily_start_limit
      redirect_to list_main_path,
                  alert: "Daily practice limit reached for '#{@problem.name}' (#{practice_daily_start_limit}/day). Try again tomorrow."
      return
    end

    submission = nil
    placeholder = nil
    Submission.transaction do
      submission = Submission.create!(
        user:     @current_user,
        problem:  @problem,
        language: viva_lang,
        source:   nil,
        source_filename: nil,
        status:   :submitted,
        submitted_at: Time.zone.now,
        ip_address: request.remote_ip
      )

      submission.viva_turns.create!(role: :system, status: :ok, content: '(interview start)')
      placeholder = submission.viva_turns.create!(role: :assistant, status: :processing, content: nil)
    end

    Llm::VivaTurnAssistJob.perform_later(submission, turn: placeholder)
    redirect_to viva_submission_path(submission)
  end

  # GET /submissions/:submission_id/viva
  def show
    load_viva_state
  end

  # POST /submissions/:submission_id/viva/turns
  def answer
    # Only the submission owner may post answers. Admins / other privileged
    # users can still VIEW (#show, #refresh stay open), but posting on
    # behalf of someone else corrupts transcript ownership — refuse.
    unless @current_user == @submission.user
      redirect_to list_main_path, alert: "You cannot post to another user's viva session." and return
    end

    case @submission.status.to_s
    when 'done', 'grader_error'
      redirect_to viva_submission_path(@submission), alert: 'This viva session has ended.' and return
    when 'evaluating'
      # Interview already ended (LLM emitted [[VIVA_DONE]]); a grade job is
      # in flight. Accepting a new student turn here would race with the
      # grader and corrupt the transcript, so refuse.
      redirect_to viva_submission_path(@submission), alert: 'Interview ended — grading in progress.' and return
    end

    if @submission.viva_turns.where(status: :processing).exists?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to viva_submission_path(@submission), alert: 'Waiting for the previous response.' }
      end
      return
    end

    student_content = params[:content].to_s.strip
    if student_content.blank?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to viva_submission_path(@submission), alert: 'Answer cannot be empty.' }
      end
      return
    end

    # Hard turn cap (design D8): at the limit we force-finish instead of
    # accepting another answer — the soft cap should normally end the
    # interview well before this fires.
    if @submission.viva_turns.where(role: :student).count >= @submission.problem.viva_hard_cap
      @submission.viva_turns.create!(role: :system, status: :ok,
        content: '(turn limit reached — the interview ends here and grading begins)')
      @submission.update!(status: :evaluating)
      Llm::VivaGradeAssistJob.perform_later(@submission)
      redirect_to viva_submission_path(@submission), notice: 'Turn limit reached — grading has started.'
      return
    end

    placeholder = nil
    Submission.transaction do
      @submission.viva_turns.create!(role: :student, status: :ok, content: student_content)
      placeholder = @submission.viva_turns.create!(role: :assistant, status: :processing, content: nil)
    end

    Llm::VivaTurnAssistJob.perform_later(@submission, turn: placeholder)

    respond_to do |format|
      format.turbo_stream { redirect_to viva_submission_path(@submission) }
      format.html { redirect_to viva_submission_path(@submission) }
    end
  end

  # POST /submissions/:submission_id/viva/turns/:turn_id/retry
  #
  # Re-runs the LLM call for a failed assistant turn. Resets the turn
  # back to :processing (clearing content + LLM metadata) and enqueues
  # a fresh VivaTurnAssistJob.
  #
  # Allowed for owner OR admin — unlike #answer (which strictly forbids
  # admin posting on behalf of the student), retry doesn't add new
  # student content; it just asks the LLM to take another shot at the
  # student's previous answer. Admins routinely rescue stuck sessions.
  #
  # Only :error turns can be retried; in-flight :processing turns are
  # left alone (they may still complete normally, and the
  # VivaTurn.fail_stale! sweeper will eventually mark genuinely stuck
  # ones as :error so they become retryable).
  def retry_turn
    turn = @submission.viva_turns.find(params[:turn_id])

    unless @current_user == @submission.user || @current_user.admin?
      redirect_to viva_submission_path(@submission),
                  alert: 'You are not allowed to retry this turn.' and return
    end

    unless turn.role == 'assistant'
      redirect_to viva_submission_path(@submission),
                  alert: 'Only interviewer turns can be retried.' and return
    end

    unless turn.status == 'error'
      redirect_to viva_submission_path(@submission),
                  alert: 'Only failed turns can be retried.' and return
    end

    case @submission.status.to_s
    when 'done', 'grader_error', 'evaluating'
      redirect_to viva_submission_path(@submission),
                  alert: 'This viva session has already ended.' and return
    end

    turn.update!(
      status:           :processing,
      content:          nil,
      llm_response_raw: nil,
      cost:             nil,
      token_count_in:   nil,
      token_count_out:  nil,
      llm_model:        nil,
      alerted:          false
    )

    Llm::VivaTurnAssistJob.perform_later(@submission, turn: turn)

    redirect_to viva_submission_path(@submission),
                notice: 'Retrying the interviewer response...'
  end

  # POST /submissions/:submission_id/viva/restart
  #
  # Practice-mode self-service retake (design D2): archives the student's
  # own session so the Start Viva button reappears. Exam mode keeps the
  # admin-only archive path (SubmissionsController#archive_viva).
  def restart
    unless @current_user == @submission.user
      redirect_to viva_submission_path(@submission), alert: 'Only the owner can restart their viva.' and return
    end
    # Non-viva submissions must never be archivable this way: viva_mode is a
    # permitted param on every problem, and archiving hides a submission from
    # main_controller's canonical max(id) pick — a grade-manipulation vector
    # if it could be triggered on an ordinary coding submission.
    unless @submission.problem.viva_exam?
      redirect_to viva_submission_path(@submission), alert: 'Restart is only available for viva exam problems.' and return
    end
    unless @submission.problem.viva_mode_practice?
      redirect_to viva_submission_path(@submission), alert: 'Restart is only available for practice-mode vivas.' and return
    end
    if @submission.viva_archived_at.present?
      redirect_to viva_submission_path(@submission), alert: 'This viva session has already been archived.' and return
    end
    if @submission.viva_turns.where(status: :processing).exists?
      redirect_to viva_submission_path(@submission), alert: 'Wait for the current response to finish first.' and return
    end

    @submission.update!(viva_archived_at: Time.zone.now)
    redirect_to list_main_path,
                notice: "Practice viva archived — start a fresh one from the problem list (limit #{practice_daily_start_limit} per day)."
  end

  # GET /submissions/:submission_id/viva/refresh
  def refresh
    load_viva_state
    render partial: 'viva_session', locals: {
      submission:   @submission,
      turns:        @turns,
      viva_grade:   @viva_grade,
      pending_turn: @pending_turn,
      finished:     @finished
    }
  end

  private

  # Resolved daily start cap for practice-mode vivas (design D2). Reused by
  # #start's rate-limit guard and #restart's notice text.
  #
  # A follow-up UI task will show "N of L starts left" on the problem
  # list/detail view; that code should read the SAME config the same way —
  # GraderConfiguration[PRACTICE_DAILY_START_LIMIT_CONF_KEY] — and apply
  # this identical positive-or-fallback guard, not just read the raw key,
  # so a blank/zero config can't be read as "unlimited" there either.
  def practice_daily_start_limit
    limit = GraderConfiguration[PRACTICE_DAILY_START_LIMIT_CONF_KEY].to_i
    limit.positive? ? limit : DAILY_START_LIMIT_FALLBACK
  end

  # Shared by #show and #refresh. The "pending" flag drives both polling
  # (keep refreshing while the backend is still doing work) and the
  # answer-form's disabled state. It's true while a turn is being
  # generated *or* the grader is running, so the UI keeps polling
  # until the grade lands or fails.
  #
  # The "finished" flag drives whether the answer form is shown at all
  # — once we're in :evaluating, :done, or :grader_error, the student
  # can't submit more answers, and the view falls through to either
  # "Grading in progress…", the grade card, or a "Grader error" alert.
  def load_viva_state
    @turns        = @submission.viva_turns.ordered
    @viva_grade   = @submission.viva_grade
    @pending_turn = @submission.viva_turns.where(status: :processing).exists? ||
                    @submission.status == 'evaluating'
    @finished     = %w[done grader_error evaluating].include?(@submission.status.to_s)

    # Retake-policy visibility (D2 follow-up): practice-mode students should
    # see how many of today's starts they have left, using the SAME count
    # #start's rate-limit guard uses (today's submissions for this
    # user+problem — the current session counts against its own budget).
    if @submission.problem.viva_mode_practice?
      used = @submission.problem.submissions
               .where(user: @submission.user)
               .where('submitted_at >= ?', Time.zone.now.beginning_of_day)
               .count
      @practice_starts_left = [practice_daily_start_limit - used, 0].max
    end
  end

  def set_problem
    @problem = Problem.find(params[:id] || params[:problem_id])
  end

  def set_submission
    @submission = Submission.find(params[:submission_id] || params[:id])
  end

  # Gates #show/#refresh: reuses the platform's existing submission-view
  # predicate (admin -> reporter -> problem-submittable gate -> owner ->
  # global `right.user_view_submission` -> per-problem `view_submission`)
  # rather than duplicating that logic here. Without this, any logged-in
  # student could read any other student's viva transcript/grade by
  # guessing sequential submission ids.
  def authorize_viva_view
    return if @current_user.can_view_submission?(@submission)

    redirect_to list_main_path, alert: 'Authorization error: you are not allowed to view this viva session.'
  end
end
