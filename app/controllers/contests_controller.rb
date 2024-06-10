class ContestsController < ApplicationController
  before_action :set_contest, only: [:show, :edit, :update, :destroy,
                                     :add_user, :add_user_from_group, :add_user_from_contest, :remove_user,:remove_all_users,
                                     :add_problem, :add_problem_from_group, :add_problem_from_contest, :remove_problem,:remove_all_problems,
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
    user = User.find(params[:user_id]) rescue nil
    render plain: nil, status: :ok and return unless user
    begin
      @contest.users << user
      render turbo_stream: turbo_stream.replace(:contest_user_table_frame, partial: 'contest_users')
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'User already exists', body_msg: e.message}
      #redirect_to group_path(@group), alert: e.message
    end
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

  private

    def set_contest
      @contest = Contest.find(params[:id])

    end

    def contests_params
      params.require(:contest).permit(:title,:enabled,:name)
    end

end
