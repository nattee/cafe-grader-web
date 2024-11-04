class ContestsController < ApplicationController
  before_action :set_contest, only: [:show, :edit, :update, :destroy, :view, :view_query,
                                     :add_users_from_csv,
                                     :show_users_query, :show_problems_query,
                                     :add_user, :add_user_by_group, :add_problem, :add_problem_by_group,
                                     :toggle, :do_all_users, :do_user, :do_all_problems, :do_problem,
                                    ]
  before_action :set_user, only: [:do_user]
  before_action :set_problem, only: [:do_problem]

  before_action :admin_authorization, except: [:user_check_in]
  before_action :check_valid_login, only: [:user_check_in]

  delegate :pluralize, to: 'ActionController::Base.helpers'

  # GET /contests
  # GET /contests.xml
  def index
    @contests = Contest.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @contests }
    end
  end

  def index_query
    render json: {data: Contest.all}
  end

  # GET /contests/1
  # GET /contests/1.xml
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @contest }
    end
  end

  # show is for manage
  # view is for spectating
  def view
  end
  
  def view_query
    render json: {data: @contest.contests_users.joins(:user).select(:id, :user_id,:login,:full_name,:remark,:seat,:last_heartbeat)}
  end

  # GET /contests/new
  # GET /contests/new.xml
  def new
    @contest = Contest.new(start: Time.zone.now, stop: Time.zone.now+3.hour)

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @contest }
    end
  end

  # GET /contests/1/edit
  def edit
  end

  # POST /contests
  # POST /contests.xml
  def create
    @contest = Contest.new(contests_params)

    respond_to do |format|
      if @contest.save
        flash[:notice] = 'Contest was successfully created.'
        format.html { redirect_to contests_path }
        format.xml  { render :xml => @contest, :status => :created, :location => @contest }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @contest.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /contests/1
  # PUT /contests/1.xml
  def update

    respond_to do |format|
      if @contest.update(contests_params)
        flash[:notice] = 'Contest was successfully updated.'
        format.html { redirect_to contest_path(@contest) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @contest.errors, :status => :unprocessable_entity }
      end
    end
  end

  def contest_action
    @contest = Contest.find(params[:contest_id])
    @toast = {title: "Contest #{@contest.name}"}
    case params[:command]
    when 'toggle'
      @contest.update(enabled: !@contest.enabled?)
      @toast[:body] = @contest.enabled? ? 'Contest was enabled.' : 'Contest was disaabled.'
    else
      @toast[:body] = "Unknown command"
    end
    render 'turbo_toast'
  end

  # --- users & problems ---
  def show_users_query
    render json: {data: @contest.contests_users.joins(:user)
      .select('contests_users.id',:user_id,:enabled, :full_name, :login, :remark, :seat)}
  end

  def show_problems_query
    render json: {data: @contest.contests_problems.joins(:problem)
      .select('contests_problems.id',:problem_id,:available,:enabled, :name, :full_name, :number)}
  end

  def do_all_users
    if params[:command] == 'enable'
      ContestUser.where(contest: @contest).update_all(enabled: true)
    elsif params[:command] == 'disable'
      ContestUser.where(contest: @contest).update_all(enabled: false)
    elsif params[:command] == 'remove'
      @contest.users.clear
    else
      return
    end
  end

  def do_user
    @toast = {title: "Contest #{@contest.name}"}
    case params[:command]
    when 'remove'
      @contest.users.delete(@user)
      @toast[:body] = "#{@user.login} was removed."
    when 'toggle'
      gu = @contest.contests_users.where(user: @user).first
      gu.update(enabled: !gu.enabled?)
      @toast[:body] = 'User was updated.'
    else
      @toast[:body] = "Unknown command"
    end
    render 'turbo_toast'
  end

  def do_all_problems
    if params[:command] == 'enable'
      ContestProblem.where(contest: @contest).update_all(enabled: true)
    elsif params[:command] == 'disable'
      ContestProblem.where(contest: @contest).update_all(enabled: false)
    elsif params[:command] == 'remove'
      @contest.problems.clear
    else
      return
    end
    render 'turbo_toast'
  end

  def do_problem
    @toast = {title: "Contest #{@contest.name}"}
    gp = @contest.contests_problems.where(problem: @problem).first
    case params[:command]
    when 'remove'
      @contest.problems.delete(@problem)
      @toast[:body] = "Problem #{@problem.name} was removed."
    when 'toggle'
      gp.update(enabled: !gp.enabled?)
      @toast[:body] = "The problem #{@problem.name} was updated."
    when 'moveup'
      gp = @contest.contests_problems.where(problem: @problem).first
      @contest.set_problem_number(@problem,(gp.number || 2) - 1.2) #instead of -1, we do -0.8 so that  it is placed "before" the original number - 1 rank
      @toast[:body] = "Problem #{@problem.name} was moved up."
    when 'movedown'
      gp = @contest.contests_problems.where(problem: @problem).first
      @contest.set_problem_number(@problem,(gp.number || 0) + 1.2) #so is here
      @toast[:body] = "Problem #{@problem.name} was moved down."
    else
      @toast[:body] = "Unknown command"
    end
    render 'turbo_toast'
  end

  def add_user
    begin
      users = User.where(id: params[:user_ids])
      @toast = @contest.add_users users
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding users failed', body_msg: e.message}
    end
  end

  def add_user_by_group
    begin
      user_ids = GroupUser.where(group_id: params[:user_group_ids]).where.not(user_id: @contest.users.ids).pluck :user_id
      user_ids = GroupUser.where(group_id: params[:user_group_ids]).pluck :user_id
      @toast = @contest.add_users User.where(id: user_ids)
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding users failed', body_msg: e.message}
    end
  end

  def add_users_from_csv
    lines = params[:user_list]

    res = @contest.add_users_from_csv(lines)
    @toast = {title: "Contest #{@contest.name}"}
    body = "#{pluralize(res[:added_users].count,'user')} were added or updated. "
    body += "#{pluralize(res[:error_logins].count,'user')} failed to be added. The first error is #{res[:first_error]}" if res[:error_logins].count > 0
    @toast[:body] = body
    render 'turbo_toast'
  end

  def add_problem
    #find return arrays of objecs
    begin
      problems = Problem.where(id: params[:problem_ids]) #this find multiple problems
      @toast = @contest.add_problems_and_assign_number(problems)
      render 'turbo_toast'
    rescue => e
      puts e.message
      puts e.backtrace
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  def add_problem_by_group
    begin
      problem_ids = GroupProblem.where(group_id: params[:problem_group_ids]).where.not(problem_id: @contest.problems.ids).pluck :problem_id
      @toast = @contest.add_problems_and_assign_number(Problem.where(id: problem_ids))
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  def user_check_in
    #ContestUser.where(id: Contest.active.joins(:contests_users).where(contests_users: {user_id: @current_user}).pluck('contests_users.id')).update_all(last_heartbeat: Time.zone.now)
    current = Time.zone.now
    last = @current_user.last_heartbeat || current
    @current_user.update(last_heartbeat: current)
    ms_since_last_check_in = ((current - last) * 1000).to_i
    if (@current_contest)
      ms_until_contest_end = ((@current_contest.stop - current) * 1000).to_i
    end
    render json: {ms_since_last_check_in: ms_since_last_check_in, ms_until_contest_end: ms_until_contest_end, current_time: current}
  end


  # DELETE /contests/1
  # DELETE /contests/1.xml
  def destroy
    @contest.destroy

    respond_to do |format|
      format.html { redirect_to(contests_url) }
      format.xml  { head :ok }
    end
  end

  def set_system_mode
    if ['standard','contest','indv-contest','analysis'].include? params[:mode]
      GraderConfiguration.where(key: 'system.mode').update(value: params[:mode])
      redirect_to contests_path, notice: 'Mode changed succesfully'
    else
      redirect_to contests_path, notice: 'Unrecognized mode'
    end
  end

  private

    def set_contest
      @contest = Contest.find(params[:id])
    end

    def set_user
      @user = User.find(params[:user_id]) rescue nil
    end

    def set_problem
      @problem = Problem.find(params[:problem_id]) rescue nil
    end

    def contests_params
      params.require(:contest).permit(:name, :description,:enabled,:lock, :start, :stop)
    end

end
