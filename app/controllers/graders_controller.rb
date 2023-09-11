class GradersController < ApplicationController

  before_action :admin_authorization

  def index
    redirect_to :action => 'list'
  end

  def list
    @graders = GraderProcess.all
    @wait_count = Job.where(status: :wait).group(:job_type).count

    @submission = Submission.order("id desc").limit(20).includes(:user,:problem)
    @backlog_submission = Submission.where('graded_at is null').includes(:user,:problem)

    @wait_compile_job_count = Job.where(job_type: :compile, status: :wait).count
    @wait_eval_job_count = Job.where(job_type: :evaluate, status: :wait).count
  end

  def set_enabled
    @grader = GraderProcess.where(id: params[:id]).first
    @grader.update(enabled: params[:enabled])
    redirect_to action: :list
  end

  def clear
    grader_proc = GraderProcess.find(params[:id])
    grader_proc.destroy if grader_proc!=nil
    redirect_to :action => 'list'
  end

  def clear_terminated
    GraderProcess.find_terminated_graders.each do |p|
      p.destroy
    end
    redirect_to :action => 'list'
  end

  def clear_all
    GraderProcess.all.each do |p|
      p.destroy
    end
    redirect_to :action => 'list'
  end

  def view
    if params[:type]=='Task'
      redirect_to :action => 'task', :id => params[:id]
    else
      redirect_to :action => 'test_request', :id => params[:id]
    end
  end

  def test_request
    @test_request = TestRequest.find(params[:id])
  end

  def task
    @task = Task.find(params[:id])
  end


  # various grader controls

  def stop 
    grader_proc = GraderProcess.find(params[:id])
    GraderScript.stop_grader(grader_proc.pid)
    flash[:notice] = 'Grader stopped.  It may not disappear now, but it should disappear shortly.'
    redirect_to :action => 'list'
  end

  def stop_all
    GraderScript.stop_graders(GraderProcess.find_running_graders + 
                              GraderProcess.find_stalled_process)
    flash[:notice] = 'Graders stopped.  They may not disappear now, but they should disappear shortly.'
    redirect_to :action => 'list'
  end

  def start_grading
    GraderScript.start_grader('grading')
    flash[:notice] = '2 graders in grading env started, one for grading queue tasks, another for grading test request'
    redirect_to :action => 'list'
  end

  def start_exam
    GraderScript.start_grader('exam')
    flash[:notice] = '2 graders in grading env started, one for grading queue tasks, another for grading test request'
    redirect_to :action => 'list'
  end

end
