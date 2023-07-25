class Grader
  # This class is the main event loop for grader process
  # It is associated with one box-id of isolate
  # Responsible for dispatching a job

  JudgeProblemPath = 'isolate_problem'
  JudgeSubmissionPath = 'isolate_submission'
  JudgeSubmissionBinPath = 'bin'
  JudgeSubmissionSourcePath = 'source'
  JudgeSubmissionLibPath = 'lib'
  JudgeSubmissionCompilePath = 'compile'

  include JudgeBase

  attr_accessor :job
  attr_reader :box_id

  def initialize(host_id,box_id)
    @box_id = box_id
    @host_id = box_id
    @grader_process = GraderProcess.find_or_create_by(box_id: box_id, host_id: host_id)
    judge_log 'Grader created'
  end

  def process_job_compile
    sub = Submission.find(@job.arg)
    compiler = Compiler.get_compiler(sub).new(@host_id,@box_id)
    result = compiler.compile(sub)

    #report compile
    judge_log "Job #{@job.to_text} completed with result #{result}"
    @job.report(result)

    #add next jobs
    if result[:compile_result] == :success
      Job.add_evaluation_jobs(sub,@job.id)
    end
  end

  def process_job_evaluate
    sub = Submission.find(@job.arg)
    param = JSON.parse(@job.param,symbolize_names: true)
    testcase = Testcase.find(param[:testcase_id])

    evaluator = Evaluator.get_evaluator(sub).new(@host_id,@box_id)
    result = evaluator.execute(sub,testcase)

    @job.report(result)

    #add scoring when all evaluation is done
    if Job.all_evaluate_job_complete(job)
      Job.add_scoring_job(sub)
    end
  end

  def process_job_scoring
    sub = Submission.find(@job.arg)
  end

  def check_and_run_job
    @job = Job.take_oldest_waiting_job(@grader_process)

    if (@job)
      judge_log "Process job #{@job.to_text}"
      @grader_process.update(task_id: @job.id)
      if @job.jt_compile?
        process_job_compile
      elsif @job.jt_evaluate?
        process_job_evaluate
      elsif @job.jt_score?
        process_job_scoring
      else
        #we don't know how to process this job, report so
        @job.report({status: :error,result: 'grader does not have handler for this job_type'})
      end
    end
    @job = nil
  end


  def main_loop
    loop do
      #fetch any job
      check_and_run_job

      #10 Hz
      sleep (0.1)
    end
  end

  # start the main loop, with the given box_id
  def self.start(box_id)
    #load parameter
    g = Grader.new(Rails.configuration.worker[:worker_id],box_id)

    #trying to connect to server, register as a new grader process

    # successfully connected, enter the loop
    puts "grader main loop started"
    g.main_loop
  end

  def self.test_job
    #init
    s = Submission.last;
    Job.delete_all
    HostProblem.where(problem: s.problem).delete_all


    Job.add_compiling_job(s)
  end
end
