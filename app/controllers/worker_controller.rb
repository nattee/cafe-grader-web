class WorkerController < ApplicationController
  skip_forgery_protection
  before_action :worker_authenticity
  # this centralize communication between worker and the web interface

  # handle receiving compiled files from worker
  def compiled_submission
    sub = Submission.find(params[:id])
    sub.compiled_files.purge
    sub.compiled_files.attach upload_compiled_params[:compiled_files]
  end

  def get_compiled_submission
    sub = Submission.find(params[:sub_id])
    compiled_file = sub.compiled_files.find(params[:attach_id])
    send_data compiled_file.download, :filename => compiled_file.filename.to_s, :type => 'application/octet-stream'
  end

  def get_manager
    dataset = Dataset.find(params[:ds_id])
    file = dataset.managers.find(params[:manager_id])
    send_data file.download, :filename => file.filename.to_s, :type => 'application/octet-stream'
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

