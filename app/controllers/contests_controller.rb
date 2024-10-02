class ContestsController < ApplicationController
  before_action :set_contest, only: [:show, :edit, :update, :destroy,
                                     :show_users_query, :show_problems_query,
                                     :add_user, :add_user_by_group, :add_problem, :add_problem_by_group,
                                     :toggle, :do_all_users, :do_user, :do_all_problems, :do_problem,
                                    ]

  before_action :admin_authorization

  # GET /contests
  # GET /contests.xml
  def index
    @contests = Contest.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @contests }
    end
  end

  # GET /contests/1
  # GET /contests/1.xml
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @contest }
    end
  end

  # GET /contests/new
  # GET /contests/new.xml
  def new
    @contest = Contest.new

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
    @contest = Contest.new(params[:contest])

    respond_to do |format|
      if @contest.save
        flash[:notice] = 'Contest was successfully created.'
        format.html { redirect_to(@contest) }
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
        format.html { redirect_to(@contest) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @contest.errors, :status => :unprocessable_entity }
      end
    end
  end

  # --- users & problems ---
  def do_all_users
    if params[:command] == 'enable'
      GroupUser.where(group: @group).update_all(enabled: true)
    elsif params[:command] == 'disable'
      GroupUser.where(group: @group).update_all(enabled: false)
    elsif params[:command] == 'remove'
      @group.users.clear
    else
      return
    end
  end

  def do_user
    case params[:command]
    when 'remove'
      @group.users.delete(@user)
      @toast = {title: "Group #{@group.name}", body: "#{@user.login} was removed."}
    when 'toggle'
      gu = @group.groups_users.where(user: @user).first
      gu.update(enabled: !gu.enabled?)
      @toast = {title: "Group #{@group.name}", body: 'User was updated.'}
    when 'make_editor'
      GroupUser.where(user: @user, group: @group).update(role: 'editor')
      @toast = {title: "Group #{@group.name}", body: "#{@user.login}'s role changed to editor."}
    when 'make_reporter'
      GroupUser.where(user: @user, group: @group).update(role: 'reporter')
      @toast = {title: "Group #{@group.name}", body: "#{@user.login}'s role changed to reporter."}
    when 'make_user'
      GroupUser.where(user: @user, group: @group).update(role: 'user')
      @toast = {title: "Group #{@group.name}", body: "#{@user.login}'s role changed to user."}
    else
    end
    render 'turbo_toast'
  end

  def do_all_problems
    if params[:command] == 'enable'
      GroupProblem.where(group: @group).update_all(enabled: true)
    elsif params[:command] == 'disable'
      GroupProblem.where(group: @group).update_all(enabled: false)
    elsif params[:command] == 'remove'
      @group.problems.clear
    else
      return
    end
    render 'turbo_toast'
  end

  def do_problem
    case params[:command]
    when 'remove'
      @group.problems.delete(@problem)
      @toast = {title: "Group #{@group.name}", body: "Problem #{@problem.name} was removed."}
    when 'toggle'
      gp = @group.groups_problems.where(problem: @problem).first
      gp.update(enabled: !gp.enabled?)
      @toast = {title: "Group #{@group.name}", body: "The problem #{@problem.name} was updated."}
    else
    end
    render 'turbo_toast'
  end

  def add_user
    begin
      users = User.find(params[:user_ids]) #this find multiple users
      @group.users << users
      @toast = {title: "Group #{@group.name}", body: "#{users.count} users were added."}
      render 'turbo_toast'
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'Adding users failed', body_msg: e.message}
    end
  end

  def add_user_by_group
    begin
      user_ids = GroupUser.where(group_id: params[:user_group_ids]).where.not(user_id: @group.users.ids).pluck :user_id
      @group.users << User.where(id: user_ids)
      @toast = {title: "Group #{@group.name}", body: "#{user_ids.count} users were added."}
      render 'turbo_toast'
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'Adding users failed', body_msg: e.message}
    end
  end

  def add_problem
    #find return arrays of objecs
    begin
      problems = Problem.find(params[:problem_ids]) #this find multiple problems
      @group.problems << problems
      @toast = {title: "Group #{@group.name}", body: "#{problems.count} problem(s) were added."}
      render 'turbo_toast'
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  def add_problem_by_group
    begin
      problem_ids = GroupProblem.where(group_id: params[:problem_group_ids]).where.not(problem_id: @group.problems.ids).pluck :problem_id
      @group.problems << Problem.where(id: problem_ids)
      @toast = {title: "Group #{@group.name}", body: "#{problem_ids.count} problems were added."}
      render 'turbo_toast'
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  def user_check_in

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

    def contests_params
      params.require(:contest).permit(:title,:enabled,:name)
    end

end
