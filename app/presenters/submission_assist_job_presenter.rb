class SubmissionAssistJobPresenter < SimpleDelegator
  # Use SimpleDelegator to forward all standard method calls to the original job object

  attr_reader :user_name, :problem_name
  attr_reader :user_id, :problem_id
  attr_reader :points

  def initialize(job, submission = nil)
    # The __setobj__ method is from SimpleDelegator
    __setobj__(job)

    @submission = submission
    @arguments = job.arguments['arguments']
    # Set attributes directly from the pre-loaded object
    if @submission
      # The user and problem associations were eager loaded (e.g., .includes(:user, :problem))
      # so these calls DO NOT hit the database.
      @user_name = @submission.user.full_name
      @user_id = @submission.user.id
      @problem_name = @submission.problem.full_name
      @problem_id = @submission.problem.id
      @points = @submission.points
    else
      # Fallback logic if needed, or simply leave attributes nil
      # ... original argument parsing logic can remain here for single initialization ...
      # (e.g., if you were to call this presenter on a single job outside the main list view)
    end
  end


  # for SubmissionAssistJob, the first argument is a submission
  def submission_id
    @submission&.id
  end

  # You can also wrap other logic here
  def detail
    # Keyword arguments are the last element in the array if it's a hash.
    last_arg = @arguments.last
    last_arg.is_a?(Hash) ? last_arg : {}
  end

  def detail_html
    h = detail
    return '' if h.empty?

    # add model detail
    html = <<~HTML
      <strong>Model:</strong> #{h['model']}
    HTML

    return html.html_safe
  end

  # Delegate the original object for Jbuilder
  def to_model
    __getobj__
  end
end
