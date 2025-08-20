class SubmissionAssistJobPresenter < SimpleDelegator
  # Use SimpleDelegator to forward all standard method calls to the original job object

  attr_reader :user_name, :problem_name

  def initialize(job)
    # The __setobj__ method is from SimpleDelegator
    __setobj__(job)
    @job_class = class_name.safe_constantize
    @arguments = job.arguments['arguments']

    # initialize submission for submission based job
    if @job_class && @job_class < Llm::SubmissionAssistJob && arguments.present?
      gid_string = @arguments.first.values.last
      if gid_string.is_a?(String)
        @submission = GlobalID::Locator.locate(gid_string) rescue nil
      end

      if @submission
        @user_name = @submission.user.full_name
        @problem_name = @submission.problem.full_name
      end
    end
  end

  # for SubmissionAssistJob, the first argument is a submission
  def submission_id
    @submission&.id
  end

  # You can also wrap other logic here
  def detail
    # Only perform this logic for your specific job types.
    return {} unless @job_class && @job_class < Llm::SubmissionAssistJob && arguments.present?

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
