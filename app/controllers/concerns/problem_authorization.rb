module ProblemAuthorization
  extend ActiveSupport::Concern

  included do
    # these funcions requires
    #   @current_user
    #   @problem
    # They are just a convenient method that can be used as a filter

    def can_edit_problem
      return true if @current_user.can_edit_problem?(@problem)
      unauthorized_redirect(msg: 'You are not authorized to edit this problem')
    end

    def can_report_problem
      return true if @current_user.can_report_problem?(@problem)
      unauthorized_redirect(msg: 'You are not authorized to analyze this problem')
    end

    # viewing is the same as submitting
    def can_view_problem
      return true if @current_user.can_view_problem?(@problem)
      unauthorized_redirect(msg: 'You are not authorized to access this problem')
    end
  end
end
