class ProblemsController < ApplicationController

  include ActiveStorage::SetCurrent

  before_action :admin_authorization, except: [:stat]
  before_action :set_problem, only: [:show, :edit, :update, :destroy, :get_statement, :toggle, :toggle_test, :toggle_view_testcase, :stat]
  before_action only: [:stat] do
    authorization_by_roles(['admin','ta'])
  end


  def index
    @problems = Problem.order(date_added: :desc)
  end


  def show
  end

  #get statement download link
  def get_statement
    unless @current_user.can_view_problem? @problem
      redirect_to list_main_path, error: 'You are not authorized to access this file'
      return
    end

    if params[:ext]=='pdf'
      content_type = 'application/pdf'
    else
      content_type = 'application/octet-stream'
    end

    filename = @problem.statement.filename.to_s
    data =@problem.statement.download

    send_data data, stream: false, disposition: 'inline', filename: filename, type: content_type
  end

  def new
    @problem = Problem.new
  end

  def create
    @problem = Problem.new(problem_params)
    if @problem.save
      redirect_to action: :index, notice: 'Problem was successfully created.'
    else
      render :action => 'new'
    end
  end

  def quick_create
    @problem = Problem.new(problem_params)
    @problem.full_name = @problem.name if @problem.full_name == ''
    @problem.full_score = 100
    @problem.available = false
    @problem.test_allowed = true
    @problem.output_only = false
    @problem.date_added = Time.new
    if @problem.save
      flash[:notice] = 'Problem was successfully created.'
      redirect_to action: :index
    else
      flash[:notice] = 'Error saving problem'
    redirect_to action: :index
    end
  end

  def edit
    @description = @problem.description
  end

  def update
    if problem_params[:statement] && problem_params[:statement].content_type != 'application/pdf'
        flash[:error] = 'Error: Uploaded file is not PDF'
        render :action => 'edit'
        return
    end
    if @problem.update(problem_params)
      flash[:notice] = 'Problem was successfully updated. '
      flash[:notice] += 'A new statement PDF is uploaded' if problem_params[:statement] 
      @problem.save
      redirect_to edit_problem_path(@problem)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @problem.destroy
    redirect_to action: :index
  end

  def toggle
    @problem.update(available: !(@problem.available) )
    respond_to do |format|
      format.js { }
    end
  end

  def toggle_test
    @problem.update(test_allowed: !(@problem.test_allowed?) )
    respond_to do |format|
      format.js { }
    end
  end

  def toggle_view_testcase
    @problem.update(view_testcase: !(@problem.view_testcase?) )
    respond_to do |format|
      format.js { }
    end
  end

  def turn_all_off
    Problem.available.all.each do |problem|
      problem.available = false
      problem.save
    end
    redirect_to action: :index
  end

  def turn_all_on
    Problem.where.not(available: true).each do |problem|
      problem.available = true
      problem.save
    end
    redirect_to action: :index
  end

  def stat
    unless @problem.available or session[:admin]
      redirect_to :controller => 'main', :action => 'list'
      return
    end
    @submissions = Submission.includes(:user).includes(:language).where(problem_id: params[:id]).order(:user_id,:id)

    #stat summary
    range =65
    @histogram = { data: Array.new(range,0), summary: {} }
    user = Hash.new(0)
    @submissions.find_each do |sub|
      d = (DateTime.now.in_time_zone - sub.submitted_at) / 24 / 60 / 60
      @histogram[:data][d.to_i] += 1 if d < range
      user[sub.user_id] = [user[sub.user_id], ((sub.try(:points) || 0) >= @problem.full_score) ? 1 : 0].max
    end
    @histogram[:summary][:max] = [@histogram[:data].max,1].max

    @summary = { attempt: user.count, solve: 0 }
    user.each_value { |v| @summary[:solve] += 1 if v == 1 }

    #for new graph
    @chart_dataset = @problem.get_jschart_history.to_json.html_safe
  end

  def manage
    @problems = Problem.order(date_added: :desc).includes(:tags)
  end

  def do_manage
    change_date_added if params[:change_date_added] == '1' && params[:date_added].strip.empty? == false
    add_to_contest if params.has_key? 'add_to_contest'
    set_available(params[:enable] == 'yes') if params[:change_enable] == '1'
    if params[:add_group] == '1'
      group = Group.find(params[:group_id])
      ok = []
      failed = []
      get_problems_from_params.each do |p|
        begin
          group.problems << p
          ok << p.full_name
        rescue => e
          failed << p.full_name
        end
      end
      flash[:success] = "The following problems are added to the group #{group.name}: " + ok.join(', ') if ok.count > 0
      flash[:alert] = "The following problems are already in the group #{group.name}: " + failed.join(', ') if failed.count > 0
    end

    if params[:add_tags] == '1'
      get_problems_from_params.each { |p| p.tag_ids += params[:tag_ids] }
    end

    redirect_to :action => 'manage'
  end

  def import
    @allow_test_pair_import = allow_test_pair_import?
  end

  def do_import
    old_problem = Problem.find_by_name(params[:name])
    if !allow_test_pair_import? and params.has_key? :import_to_db
      params.delete :import_to_db
    end
    @problem, import_log = Problem.create_from_import_form_params(params,
                                                                  old_problem)

    if !@problem.errors.empty?
      render :action => 'import' and return
    end

    if old_problem!=nil
      flash[:notice] = "The test data has been replaced for problem #{@problem.name}"
    end
    @log = import_log
  end

  def remove_contest
    problem = Problem.find(params[:id])
    contest = Contest.find(params[:contest_id])
    if problem!=nil and contest!=nil
      problem.contests.delete(contest)
    end
    redirect_to :action => 'manage'
  end

  ##################################
  protected

  def allow_test_pair_import?
    if defined? ALLOW_TEST_PAIR_IMPORT
      return ALLOW_TEST_PAIR_IMPORT
    else
      return false
    end
  end

  def change_date_added
    problems = get_problems_from_params
    date = Date.parse(params[:date_added])
    problems.each do |p|
      p.date_added = date
      p.save
    end
  end

  def add_to_contest
    problems = get_problems_from_params
    contest = Contest.find(params[:contest][:id])
    if contest!=nil and contest.enabled
      problems.each do |p|
        p.contests << contest
      end
    end
  end

  def set_available(avail)
    problems = get_problems_from_params
    problems.each do |p|
      p.available = avail
      p.save
    end
  end

  def get_problems_from_params
    problems = []
    params.keys.each do |k|
      if k.index('prob-')==0
        name, id, order = k.split('-')
        problems << Problem.find(id)
      end
    end
    problems
  end

  def get_problems_stat
  end

  private

    def set_problem
      @problem = Problem.find(params[:id])
    end

    def problem_params
      params.require(:problem).permit(:name, :full_name, :full_score, :change_date_added, :date_added, :available,
                                      :test_allowed, :output_only, :url, :description, :statement, :description, tag_ids:[])
    end

    def description_params
      params.require(:description).permit(:body, :markdowned)
    end

end
