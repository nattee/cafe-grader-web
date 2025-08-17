class GradersController < ApplicationController
  before_action :set_problem, only: [:edit_job_type, :set_enabled, :update
                                    ]

  before_action :admin_authorization

  def index
    @graders = GraderProcess.all
    @wait_count = Job.where(status: :wait).group(:job_type).count

    @submission = Submission.order("id desc").limit(20).includes(:user, :problem)
    @backlog_submission = Submission.where('graded_at is null').includes(:user, :problem)

    @wait_compile_job_count = Job.where(job_type: :compile, status: :wait).count
    @wait_eval_job_count = Job.where(job_type: :evaluate, status: :wait).count
  end

  def edit_job_type
    if @grader.job_type.blank?
      @job_type = Job.job_types.keys
    else
      @job_type = @grader.job_type.split
    end
  end

  def update
    result = []
    Job.job_types.each do |k, v|
      param_name = "jt-#{k}"
      result << k if params[param_name] == 'on'
    end
    @grader.update(job_type: result.join(' '))

    # i don't know why but when submit is made via form's input{type: 'submit'}, we don't need to call turbo_stream.replace
    # see "set_enabled" which is acticated by form's button element. There, we NEED explicit call to turbo_stream.replace
    render partial: 'grader', locals: {grader: @grader}
    # render turbo_stream: turbo_stream.replace( helpers.dom_id(@grader), partial: 'grader', locals: {grader: @grader})
  end

  def set_enabled
    @grader.update(enabled: params[:enabled])

    # render partial: 'grader', locals: {grader: @grader}
    render turbo_stream: turbo_stream.replace(helpers.dom_id(@grader), partial: 'grader', locals: {grader: @grader})
  end

  # solid_queue dashboard
  def queues
  end

  def queues_query
    jobs_scope = SolidQueue::Job.all
    if params[:status].present?
      jobs_scope = jobs_scope
    end

    raw_jobs = jobs_scope.order(created_at: :desc).first(100)
    @jobs = raw_jobs.map { |job| SubmissionAssistJobPresenter.new(job) }
  end

  private

    def set_problem
      @grader = GraderProcess.find(params[:id])
    end
end
