class GroupsController < ApplicationController
  before_action :set_group, only: [:show, :edit, :update, :destroy,
                                   :add_user, :remove_user,:remove_all_user,
                                   :add_problem, :remove_problem,:remove_all_problem,
                                   :toggle, :set_user_role,
                                  ]
  before_action :group_editor_authorization

  # GET /groups
  def index
    @groups = @current_user.editable_groups
  end

  # GET /groups/1
  def show
  end

  # GET /groups/new
  def new
    @group = Group.new
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  def create
    @group = Group.new(group_params)

    if @group.save
      redirect_to @group, notice: 'Group was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /groups/1
  def update
    if @group.update(group_params)
      redirect_to @group, notice: 'Group was successfully updated.'
    else
      render :edit
    end
  end

  def set_user_role
    user = User.find(params[:user_id])
    GroupUser.where(user: user, group: @group).update(role: params[:role])
    render turbo_stream: turbo_stream.replace(:user_table_frame, partial: 'group_users')
  end

  # DELETE /groups/1
  def destroy
    @group.destroy
    redirect_to groups_url, notice: 'Group was successfully destroyed.'
  end

  def toggle
    @group.enabled = @group.enabled? ? false : true
    @group.save
  end

  def remove_all_user
    @group.users.clear
    redirect_to group_path(@group), alert: 'All users removed'
  end

  def remove_all_problem
    @group.problems.clear
    redirect_to group_path(@group), alert: 'All problems removed'
  end

  def add_user
    user = User.find(params[:user_id]) rescue nil
    render plain: nil, status: :ok and return unless user
    begin
      @group.users << user
      #redirect_to group_path(@group), flash: { success: "User #{user.login} was add to the group #{@group.name}"}
      render turbo_stream: turbo_stream.replace(:user_table_frame, partial: 'group_users')
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'User already exists', body_msg: e.message}
      #redirect_to group_path(@group), alert: e.message
    end
  end

  def remove_user
    user = User.find(params[:user_id])
    @group.users.delete(user)
    #redirect_to group_path(@group), flash: {success: "User #{user.login} was removed from the group #{@group.name}"}
    render turbo_stream: turbo_stream.replace(:user_table_frame, partial: 'group_users')
  end

  def add_problem
    problem = Problem.find(params[:problem_id]) rescue nil
    render plain: nil, status: :ok and return unless problem
    begin
      @group.problems << problem
      #redirect_to group_path(@group), flash: {success: "Problem #{problem.name} was add to the group #{@group.name}" }
      render turbo_stream: turbo_stream.replace(:problem_table_frame, partial: 'group_problems')
    rescue => e
      render partial: 'shared/msg_modal_show', locals: {do_popup: true, header_msg: 'Problem already exists', body_msg: e.message}
      #redirect_to group_path(@group), alert: e.message
    end
  end


  def remove_problem
    problem = Problem.find(params[:problem_id])
    @group.problems.delete(problem)
    #redirect_to group_path(@group), flash: {success: "Problem #{problem.name} was removed from the group #{@group.name}" }
    render turbo_stream: turbo_stream.replace(:problem_table_frame, partial: 'group_problems')
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_group
      @group = Group.find(params[:id])
    end

    # check if the user can manage group
    # admin always has the right
    def group_editor_authorization
      return true if @current_user.admin?
      return true if @current_user.editable_groups.where(id: @group)
      unauthorized_redirect("You cannot manage group #{group.name}.");
    end

    # Only allow a trusted parameter "white list" through.
    def group_params
      params.require(:group).permit(:name, :description, :enabled)
    end
end
