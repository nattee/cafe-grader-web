class ContestsController < ApplicationController
  before_action :set_contest, only: [:show, :edit, :update, :destroy,
                                     :add_user, :remove_user,:remove_all_users,
                                     :add_problem, :remove_problem,:remove_all_problems,
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


  def add_user
    users = nil
    if params.has_key? :user_id
      users = User.where(id: params[:user_id])
    elsif params.has_key? :user_group_id
      users = User.where(id: Group.joins(:users).where('groups.id': params[:user_group_id]).pluck('users.id') )
    end
    if users.nil?
      @toast = {title: 'Contest user are NOT update',body: 'No user given'}
    else
      begin
        @toast = @contest.add_users(users)
        @clear_form = true
      rescue => e
        @toast = {title: 'Errors', body: e.message}
      end
    end
    render 'user_change'
  end

  def add_problem
    problems = nil
    if params.has_key? :problem_id
      problems = Problem.where(id: params[:problem_id])
    elsif params.has_key? :problem_group_id
      problems = Problem.where(id: Group.joins(:problems).where('groups.id': params[:problem_group_id]).pluck('problems.id') )
    end
    if problems.nil?
      @toast = {title: 'Contest problem are NOT update',body: 'No problem given'}
    else
      begin
        @toast = @contest.add_problems(problems)
        @clear_form = true
      rescue => e
        @toast = {title: 'Errors', body: e.message}
      end
    end
    render 'problem_change'
  end

  def remove_all_users
    @contest.users.delete_all
    render 'user_change'
  end

  def remove_user
    @contest.users.delete(params[:user_id])
    render 'user_change'
  end

  def remove_all_problems
    @contest.problems.delete_all
    render 'problem_change'
  end

  def remove_problem
    @contest.problems.delete(params[:problem_id])
    render 'problem_change'
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
