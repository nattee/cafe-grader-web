class CommentsController < ApplicationController
  include ProblemAuthorization

  HINT_VIEW_METHOD = %i[ show acquire ]
  HINT_EDIT_METHOD = %i[ edit update ]

  before_action :check_valid_login
  before_action :set_problem
  before_action :set_hint, only: HINT_EDIT_METHOD + HINT_VIEW_METHOD
  before_action :can_view_problem, only: HINT_VIEW_METHOD
  before_action :can_edit_problem, except: HINT_EDIT_METHOD

  # -- problem comment section --
  # -- (this is mainly about hints) --
  def manage_problem
    @hint = Comment.find(params[:null][:hint_id]) rescue nil
    if params[:button] == 'add'
      @hint = @problem.hints.create(user: @current_user, kind: 'hint')
    elsif params[:button] == 'delete'
      @hint.destroy if @hint
      @hint = @problem.hints.first
    end
  end

  def edit
    render turbo_stream: [
      turbo_stream.update("hint_detail", partial: 'hint_edit', locals: {hint: @hint})
    ]
  end

  def update
    hint_params = params.require(:comment).permit(:body, :title, :cost, :kind)
    if @hint.update(hint_params)
      @toast = {title: "Problem #{@problem.name}'s hint", body: "Hint #{@hint.title} updated"}
    else
      error_html = "<ul>#{@hint.errors.full_messages.map { |m| "<li>#{m}</li>" }.join}</ul>"
      render partial: 'msg_modal_show', locals: {do_popup: true,
                                                 header_msg: 'Hint update error',
                                                 header_class: 'bg-danger-subtle',
                                                 body_msg: error_html.html_safe}
      return
    end
    render :manage_problem
  end

  def acquire
    if @hint.acquirable_by?(@current_user)
      @hint.comment_reveals.create(user: @current_user)
      @toast = {title: "Hint acquired", body: "You received the hint. It can now be viewed at any time."}
      render 'problems/helpers'
    else
      render partial: 'msg_modal_show', locals: {do_popup: true,
                                                 header_msg: 'Hint acquisition failed',
                                                 header_class: 'bg-danger-subtle',
                                                 body_msg: "You don't have permission to acquire this hint"}
    end
  end

  def show
    # TODO: need to check whether the user can view this hint
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_problem
      @problem = Problem.find(params[:problem_id])
    end

    def set_hint
      @hint = @problem.hints.where(id: params[:id]).take
    end
end
