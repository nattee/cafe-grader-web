class WorkerController < ApplicationController
  skip_forgery_protection
  before_action :worker_authenticity
  # this centralize communication between worker and the web interface

  def compiled_submission
    sub = Submission.find(params[:id])
    sub.compiled_files.purge
    sub.compiled_files.attach upload_compiled_params[:compiled_files]
  end


  private
    # make sure that this is the worker that we allow
    # we don't use rails authenticity token here
    def worker_authenticity
      #TODO: skeleton
      return false
    end

    def upload_compiled_params
      return params.permit({compiled_files: []})
    end
end

