module Llm
  class BaseLlmJob < ApplicationJob
    # retry policies, subclasses can inherit or override.
    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
    retry_on ActiveRecord::ConnectionTimeoutError, wait: 10.seconds, attempts: 3

    # The `**job_args` will capture any additional keyword arguments (like `special_arg: 'value'`)
    # into a hash. If no extra arguments are passed, it will be an empty hash.
    def perform(submission, **job_args)
      Rails.logger.info "Starting #{service_class.name} for Submission ##{submission.id} with args: #{job_args.inspect}"

      # Now, we pass the submission AND expand the `job_args` hash back into
      # keyword arguments for the service's `.call` method.
      result = service_class.call(submission: submission, **job_args)

      if result
        Rails.logger.info "Successfully completed #{service_class.name} for Submission ##{submission.id}."
      else
        Rails.logger.warn "#{service_class.name} failed for Submission ##{submission.id}. The service handled the error."
      end
    rescue => e
      Rails.logger.error "An unexpected error occurred in #{self.class.name} for Submission ##{submission.id}: #{e.message}"
      raise e # Re-raise to let the job runner mark it as failed.
    end

    private

    # This is the "template method" that all subclasses MUST implement.
    # It tells the base job which service object to use.
    def service_class
      raise NotImplementedError, "You must implement #service_class in a subclass of BaseLlmJob"
    end
  end
end
