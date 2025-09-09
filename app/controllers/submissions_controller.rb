class SubmissionsController < ApplicationController
  include ProblemAuthorization
  include SubmissionAuthorization

  before_action :check_valid_login

  before_action :set_submission, only: [:show, :show_comments, :download, :compiler_msg, :rejudge, :set_tag, :edit, :evaluations]
  before_action :set_problem, only: %i[ edit direct_edit_problem rejudge set_tag ]
  before_action :set_language, only: %i[ edit direct_edit_problem ]

  before_action :can_view_submission, only: [:show, :show_comments, :download, :edit, :evaluations]
  before_action :can_view_problem, only: [ :direct_edit_problem ]
  before_action :can_edit_problem, only: [:rejudge, :set_tag]

  # GET /submissions
  # GET /submissions.json
  # Show problem selection and user's submission of that problem
  def index
    @user = @current_user
    @problems = @user.problems_for_action(:submit)

    if params[:problem_id]==nil
      @problem = nil
      @submissions = nil
    else
      @problem = Problem.find(params[:problem_id]) rescue nil
      if (@problem == nil) || (! @user.can_view_problem?(@problem))
        redirect_to list_main_path
        flash[:error] = 'Authorization error: You have no right to view submissions for this problem'
        return
      end
      @submissions = Submission.where(user: @user, problem: @problem).order(id: :desc)

      # when in contest mode, show only submission during this contest
      @submissions = @submissions.where(submitted_at: @current_user.active_contests_range) if GraderConfiguration.contest_mode?

      @sub_details = Hash.new { |h, k| h[k] = {} }
      Comment
        .where(kind: ['llm_assist'], commentable_id: @submissions.ids)
        .group(:commentable_id)
        .select(:commentable_id, "count(comments.id) as llm_count", "sum(comments.cost) as llm_cost")
        .each { |row| @sub_details[row.commentable_id] = { count: row.llm_count, cost: row.llm_cost } }
    end
  end

  # GET /submissions/1
  # GET /submissions/1.json
  def show
    # log the viewing
    user = User.find(session[:user_id])
    SubmissionViewLog.create(user_id: session[:user_id], submission_id: @submission.id) unless user.admin?

    if (user.id != @submission.user.id) && !user.admin? && GraderConfiguration.get('system.mode') == "contest"
      unauthorized_redirect(msg: "You are not authorized to view this submission")
    end

    # @evaluations = @submission.evaluations.joins(:testcase).includes(:testcase).order(:group, :num)
    #  .select(:num, :group, :group_name, :weight, :time, :memory, :score, :testcase_id, :result_text, :result)
    @testcases = @submission.problem.live_dataset.testcases.order(:group, :num)
    @evaluations_by_tcid = Evaluation.where(submission: @submission, testcase: @testcases.ids).index_by(&:testcase_id)

    # LLM models for help
    # See config/llm.yml
    @models = Rails.configuration.llm[:provider].keys
  end

  # as Turbo
  # show all comments
  def show_comments
    render turbo_stream: turbo_stream.update(:submission_comments, partial: 'comments', locals: {submission: @submission})
  end

  # on-site new submission on specific problem
  def direct_edit_problem
    @last_sub = @current_user.last_submission_by_problem(@problem)
    @models = [] # won't allow llm models on the first submission
    render 'edit'
  end

  # GET /submissions/1/edit
  def edit
    @last_sub = @current_user.last_submission_by_problem(@problem)
    user = User.find(session[:user_id])

    if (user.id != @submission.user.id) && !user.admin? && GraderConfiguration.get('system.mode') == "contest"
      unauthorized_redirect(msg: "You are not authorized to view this submission")
    end

    @models = Rails.configuration.llm[:provider].keys
  end

  # as Turbo
  def get_latest_submission_status
    @problem = Problem.find(params[:pid])
    @submission = @current_user.last_submission_by_problem(@problem)
    @delay_value = @submission.nil? ? -1 : (Time.zone.now - @submission.submitted_at).clamp(1, 10).to_i * 1000
    render turbo_stream: [
      turbo_stream.update("latest_status",
                           partial: 'submission_short',
                           locals: {submission: @submission,
                                    refresh_if_not_graded: @delay_value > 0,
                                    show_id: true,
                                    sub_count: @submission&.number,
                                    show_button: false })
    ]
  end
  # Turbo render evaluations as modal popup
  def evaluations
    @testcases = @submission.problem.live_dataset.testcases.order(:group, :num)
    @evaluations_by_tcid = Evaluation.where(submission: @submission, testcase: @testcases.ids).index_by(&:testcase_id)
    render partial: 'msg_modal_show', locals: { do_popup: true, header_msg: 'Evaluation Details', body_msg: render_to_string(partial: 'evaluations', locals: {testcases: @testcases, evaluations_by_tcid: @evaluations_by_tcid}) }
  end

  def download
    if @submission.language.binary? && @submission.binary
      send_data @submission.binary, filename: @submission.download_filename, type: @submission.content_type || 'application/octet-stream', disposition: 'attachment'
      return
    end

    # no binary, send the source
    send_data(@submission.source, {filename: @submission.download_filename, type: 'text/plain'})
  end

  def compiler_msg
    render partial: "msg_modal_show", locals: {do_popup: true, header_msg: "Compiler message for ##{@submission.id}", body_msg: "<pre>#{@submission.compiler_message}</pre>".html_safe}
  end

  # GET /submissions/:id/rejudge
  def rejudge
    # @task = @submission.task
    # @task.status_inqueue! if @task

    # add lower priority job
    @submission.add_judge_job(@submission.problem.live_dataset, -10)
    respond_to do |format|
      format.js
    end
  end

  def set_tag
    @submission.update(tag: params[:tag])
    redirect_to @submission
  end

protected
  def set_submission
    @submission = Submission.find(params[:id])
  end

  def set_problem
    @problem = @submission.problem if @submission
    @problem = Problem.find(params[:problem_id]) unless @problem
  end

  # need set_problem first
  def set_language
    problem_lang = Language.find(@problem.get_permitted_lang_as_ids[0]) rescue nil
    @language_forced = @problem.get_permitted_lang_as_ids.count == 1
    if @language_forced
      @language = problem_lang
    else
      @language = nil
      # this maybe called when @submission is nil
      @language = @submission&.language || @current_user.default_language || problem_lang || Language.first
    end

    @as_binary = @language.binary?
  end
end
