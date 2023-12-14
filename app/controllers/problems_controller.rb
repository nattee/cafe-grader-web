class ProblemsController < ApplicationController

  include ActiveStorage::SetCurrent

  before_action :set_problem, only: [:show, :edit, :update, :destroy, :get_statement, :get_attachment,
                                     :toggle, :toggle_test, :toggle_view_testcase, :stat,
                                     :add_dataset,:import_testcases, :view_live_testcases
                                    ]

  before_action :admin_authorization, except: [:stat, :get_statement, :get_attachment]
  before_action :check_valid_login, only: [:stat, :get_statement, :get_attachment]
  before_action :can_view_problem, only: [:get_statement, :get_attachment]
  before_action only: [:stat] do
    authorization_by_roles(['admin','ta'])
  end


  def index
    tc_count_sql = Testcase.joins(:dataset).group('datasets.problem_id').select('datasets.problem_id,count(testcases.id) as tc_count').to_sql
    ms_count_sql = Submission.where(tag: 'model').group(:problem_id).select('count(*) as ms_count, problem_id').to_sql
    @problems = Problem.joins(:datasets)
      .joins("LEFT JOIN (#{tc_count_sql}) TC ON problems.id = TC.problem_id")
      .joins("LEFT JOIN (#{ms_count_sql}) MS ON problems.id = MS.problem_id")
      .includes(:tags).order(date_added: :desc).group('problems.id')
      .select("problems.*","count(datasets_problems.id) as dataset_count, MIN(TC.tc_count) as tc_count")
      .select("MIN(MS.ms_count) as ms_count")
      .with_attached_statement
    @multi_contest = GraderConfiguration.multicontests?
  end


  # as turbo
  def add_dataset
    @dataset = @problem.datasets.create(name: @problem.get_next_dataset_name)
    render 'datasets/update'
  end

  def view_live_testcases
    @dataset = @problem.live_dataset
  end

  #get statement download link
  def get_statement
    filename = @problem.name
    data = @problem.statement.download
    send_data data, type: 'application/pdf',  disposition: 'inline', filename: filename
  end

  #get attachment
  def get_attachment
    filename = @problem.attachment.filename.to_s
    data = @problem.attachment.download
    send_data data, disposition: 'inline', filename: filename
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

    # if permitted_lang not blank, it means the user has some intent to limit
    # submittible language
    @permitted_lang_ids = @problem.get_permitted_lang_as_ids unless @problem.permitted_lang.blank?
  end

  def update
    permitted_lang_as_string = params[:problem][:permitted_lang].map { |x| Language.find(x.to_i).name unless x.blank? }.join(' ')
    @problem.permitted_lang = permitted_lang_as_string
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
    Problem.where(available: true).update_all(available: false)
    redirect_to action: :index
  end

  def turn_all_on
    Problem.where(available: false).update_all(available: true)
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
      user[sub.user_id] = [user[sub.user_id], ((sub.try(:points) || 0) >= 100) ? 1 : 0].max
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
    problems = get_problems_from_params

    change_date_added(problems) if params[:change_date_added] == '1' && params[:date_added].strip.empty? == false
    add_to_contest(problems) if params.has_key? 'add_to_contest'
    problems.update_all(available: params[:enable] == 'yes') if params[:change_enable] == '1'
    problems.each { |p| p.tag_ids += params[:tag_ids] } if params[:add_tags] == '1'

    problems.update_all(permitted_lang: Language.where(id: params[:lang_ids]).pluck(:name).join(' ')) if params[:set_languages] == '1'

    #add to groups
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


    redirect_to :action => 'manage'
  end

  def import
    @allow_test_pair_import = allow_test_pair_import?
  end


  # import as a new problem
  def do_import
    unless params[:problem][:file]
      @errors = ['You must upload a valid ZIP file']
      render :import and return
    end
    name = params[:problem][:name]
    uploaded_file_path = params[:problem][:file].to_path

    pi = ProblemImporter.new

    # unzip uploaded file to raw folder
    extracted_path = pi.unzip_to_dir(
      uploaded_file_path,
      name,
      Rails.configuration.worker[:directory][:judge_raw_path])

    if pi.errors.count > 0
      @errors = pi.errors
      render :import and return
    end

    # load data
    memory_limit = params[:problem][:memory_limit]
    memory_limit = 512 if memory_limit.blank?
    time_limit = params[:problem][:time_limit]
    time_limit = 1 if time_limit.blank?

    pi.import_dataset_from_dir(extracted_path, params[:problem][:name],
      full_name: params[:problem][:full_name],
      input_pattern: params[:problem][:input_pattern],
      sol_pattern: params[:problem][:sol_pattern],
      delete_existing: params[:problem][:replace] == '1',
      memory_limit: memory_limit,
      time_limit: time_limit,
    )

    if pi.errors.count > 0
      @errors = pi.errors
      render :import and return
    else
      @log = pi.log
      @problem = pi.problem
    end
  end

  # import into existing problem
  def import_testcases
    unless params[:import][:file]
      @errors = ['There is no uploaded file']
      return
    end

    replacing = params[:import][:target] == 'replace'
    uploaded_file_path = params[:import][:file].to_path

    pi = ProblemImporter.new

    # unzip uploaded file to raw folder
    extracted_path = pi.unzip_to_dir(
      uploaded_file_path,
      @problem.name,
      Rails.configuration.worker[:directory][:judge_raw_path])

    if pi.errors.count > 0
      @errors = pi.errors
      render :import and return
    end

    if replacing
      @dataset = @problem.datasets.where(id: params[:import][:dataset]).first
      WorkerDataset.where(dataset_id: @dataset).delete_all
    end

    # load data
    pi.import_dataset_from_dir( extracted_path, @problem.name,
                                full_name: @problem.full_name,
                                input_pattern: params[:import][:input_pattern],
                                sol_pattern: params[:import][:sol_pattern],
                                dataset: @dataset,
                                do_statement: false,
                                do_checker: false,
                                do_cpp_extras: false,
                                do_solutions: false
                              )
    @updated = 'Testcases has been imported'
    @log = pi.log
    @problem = pi.problem
    @dataset = pi.dataset
    @problem.datasets.reload
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


  # for bulk manage
  def change_date_added(problems)
    date = Date.parse(params[:date_added])
    problems.update_all(date_added: date)
  end

  def add_to_contest(problems)
    contest = Contest.find(params[:contest][:id])
    if contest!=nil and contest.enabled
      problems.each do |p|
        p.contests << contest
      end
    end
  end


  def set_permitted_lang(lang_ids)

  end

  def get_problems_from_params
    ids = []
    params.keys.each do |k|
      if k.index('prob-')==0
        #name, id, order = k.split('-')
        #problems << Problem.find(id)
        ids << k.split('-')[1]
      end
    end
    return Problem.where(id: ids)
  end

  def get_problems_stat
  end

  private

    def set_problem
      @problem = Problem.find(params[:id])
    end

    def problem_params
      params.require(:problem).permit(:name, :full_name, :change_date_added, :date_added, :available, :compilation_type,
                                      :difficulty,:attachment, :statement,
                                      :test_allowed, :output_only, :url, :description, :description, tag_ids:[])
    end

    def description_params
      params.require(:description).permit(:body, :markdowned)
    end

    def can_view_problem
      unauthorized_redirect('You are not authorized to access this problem') unless @current_user.can_view_problem?(@problem)
    end

end
