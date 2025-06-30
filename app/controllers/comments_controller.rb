class CommentsController < ApplicationController
  include ProblemAuthorization
  include SubmissionAuthorization

  HINT_VIEW_METHOD = %i[ show_hint acquire ]
  HINT_EDIT_METHOD = %i[ edit update ]
  PROBLEM_METHOD = HINT_VIEW_METHOD + HINT_EDIT_METHOD + %i[ manage_problem ]


  SUB_COMMENT_VIEW_METHOD = %i[ show_assist ]

  before_action :check_valid_login

  # for problem hint
  before_action :set_problem, only: PROBLEM_METHOD
  before_action :set_hint, only: HINT_EDIT_METHOD + HINT_VIEW_METHOD

  # for submission comment
  before_action :set_submission, only: SUB_COMMENT_VIEW_METHOD
  before_action :set_sub_comment, only: SUB_COMMENT_VIEW_METHOD

  # authorization
  before_action :can_edit_problem, except: HINT_EDIT_METHOD
  before_action :can_view_problem, only: HINT_VIEW_METHOD + SUB_COMMENT_VIEW_METHOD
  before_action :can_view_submission, only: SUB_COMMENT_VIEW_METHOD

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

  def show_hint
    # TODO: need to check whether the user can view this hint
    @header_msg = "Hint #{@hint.title}"
    @body_msg = @hint.body || '-- blank --'
    render :show
  end

  # show LLM assist
  # need submission and comment_id
  def show_assist
    @header_msg = "#{@comment.title}"
    @body_msg = @comment.body || '-- blank --'
    render :show
  end

  def show_for_submission
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_problem
      @problem = Problem.find(params[:problem_id])
    end

    def set_submission
      @submission = Submission.find(params[:submission_id])
    end

    def set_hint
      @hint = @problem.hints.where(id: params[:id]).take
    end

    def set_sub_comment
      @comment = @submission.comments.where(id: params[:id]).take
    end
end
