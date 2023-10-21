class SubmissionsController < ApplicationController
  before_action :set_submission, only: [:show,:download,:compiler_msg,:rejudge,:set_tag, :edit]
  before_action :check_valid_login
  before_action :submission_authorization, only: [:show, :download, :edit]
  before_action only: [:rejudge, :set_tag] do authorization_by_roles([:ta]) end

  # GET /submissions
  # GET /submissions.json
  # Show problem selection and user's submission of that problem
  def index
    @user = @current_user
    @problems = @user.available_problems

    if params[:problem_id]==nil
      @problem = nil
      @submissions = nil
    else
      @problem = Problem.find_by_id(params[:problem_id])
      if (@problem == nil) or (not @problem.available)
        redirect_to list_main_path
        flash[:error] = 'Authorization error: You have no right to view submissions for this problem'
        return
      end
      @submissions = Submission.find_all_by_user_problem(@user.id, @problem.id).order(id: :desc)
    end
  end

  # GET /submissions/1
  # GET /submissions/1.json
  def show
    #log the viewing
    user = User.find(session[:user_id])
    SubmissionViewLog.create(user_id: session[:user_id],submission_id: @submission.id) unless user.admin?

    @evaluations = @submission.evaluations.joins(:testcase).includes(:testcase).order(:group, :num)
      .select(:num,:group,:group_name,:weight, :time, :memory, :score, :testcase_id, :result_text)


  end

  def download
    send_data(@submission.source, {:filename => @submission.download_filename, :type => 'text/plain'})
  end

  def compiler_msg
    #render partial: "shared/msg_modal_show", locals: {header_msg: 'Compiler message', body_msg: @submission.compiler_message}
    render partial: "shared/msg_modal_show", locals: {do_popup: true, header_msg: 'Compiler message', body_msg: @submission.compiler_message}
  end

  #on-site new submission on specific problem
  def direct_edit_problem
    @problem = Problem.find(params[:problem_id])
    unless @current_user.can_view_problem?(@problem)
      unauthorized_redirect
      return
    end
    @source = ''
    if (params[:view_latest])
      sub = Submission.find_last_by_user_and_problem(@current_user.id,@problem.id)
      @source = @submission.source.to_s if @submission and @submission.source
    end
    @lang_id = @current_user.default_language || Language.first.id
    render 'edit'
  end

  # GET /submissions/1/edit
  def edit
    @source = @submission.source.to_s
    @problem = @submission.problem
    @lang_id = @submission.language_id || @current_user.default_language || Language.first.id
  end


  def get_latest_submission_status
    @problem = Problem.find(params[:pid])
    @submission = Submission.find_last_by_user_and_problem(params[:uid],params[:pid])
    respond_to do |format|
      format.js
    end
  end

  # GET /submissions/:id/rejudge
  def rejudge
    #@task = @submission.task
    #@task.status_inqueue! if @task

    #add lower priority job
    @submission.add_judge_job(@submission.problem.live_dataset,-10)
    respond_to do |format|
      format.js
    end
  end

  def set_tag
    @submission.update(tag: params[:tag])
    redirect_to @submission
  end

protected

  def submission_authorization
    #admin always has privileged
    return true if @current_user.admin?
    return true if @current_user.has_role?('ta') && (['show','download'].include? action_name)

    sub = Submission.find(params[:id])
    if @current_user.available_problems.include? sub.problem
      return true if GraderConfiguration["right.user_view_submission"] or sub.user == @current_user
    end

    #default to NO
    unauthorized_redirect
    return false
  end
  
  def set_submission
    @submission = Submission.find(params[:id])
  end

    
end
