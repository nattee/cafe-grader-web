module ProblemAuthorization
  extend ActiveSupport::Concern

  included do
    # these funcions requires 
    #   @current_user
    #   @problem


    def can_edit_problem
      return true if @current_user.admin?
      return true if @current_user.problems_for_action(:edit).where(id: @problem).any?
      unauthorized_redirect(msg: 'You are not authorized to edit this problem')
    end

    def can_report_problem
      return true if @current_user.admin?
      return true if @current_user.problems_for_action(:report).where(id: @problem).any?
      unauthorized_redirect(msg: 'You are not authorized to analyze this problem')
    end

    def can_view_problem
      return true if @current_user.admin?

      #if a user is a reporter or an editor, they can access disabled problem, which is not allowed in problems_for_action(:submit)
      return true if @current_user.problems_for_action(:report).where(id: @problem).any? 
      return true if @current_user.problems_for_action(:submit).where(id: @problem).any?
      unauthorized_redirect(msg: 'You are not authorized to access this problem')
    end

  end

end

