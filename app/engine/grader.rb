class Grader
  # This class is the main event loop for grader process
  # It is associated with one box-id of isolate
  # Responsible for dispatching a job

  JudgeProblemPath = 'isolate_problem'
  JudgeSubmissionPath = 'isolate_submission'
  JudgeSubmissionBinPath = 'bin'
  JudgeSubmissionSourcePath = 'source'
  JudgeSubmissionLibPath = 'lib'

  attr_accessor :job
  attr_reader :box_id

  def initialize(box_id)
    @box_id = box_id
  end

  def process_job_compile
    sub = Submission.find(@job.arg)
    compiler = Compile.get_compiler(sub)
    result = compiler.compile(sub)

    #report compile
    @job.report(result)

    #add next jobs
    if result[:compile_result] == :success
      sub.problem.active_dataset.testcases.each do |tp|
        Job.add_evaluation_jobs(sub,tp)
      end
    end
  end

  def process_job_evaluate
    sub = Submission.find(@job.arg)
    param = JSON.parse(@job.param,symbolize_names: true)
    testcase = Testcase.find(param[:testcase_id])

    evaluator = Evaluator.get_evaluator(sub)
    result = evaluator.evaluate(sub,testcase)

    @job.report(:success, result)

    #add scoring when all evaluation is done
    if Job.all_evaluate_job_complete(job)
      Job.add_scoring(sub)
    end
  end

  def process_job_scoring
    sub = Submission.find(@job.arg)
  end

  def run_job
    if @job.job_type == :compile
      process_job_compile
    elsif @job.job_type == :evaluate
      process_job_evaluate
    else
      #we don't know how to process this job, report so
      @job.report(:error,'grader does not have handler for this job_type')
    end
  end


  def main_loop
    loop do

      #fetch any job
      @job = Job.take_oldest_waiting_job

      run_job if (@job)

      @job = nil

      #10 Hz
      sleep (0.1)
    end
  end

  # start the main loop, with the given box_id
  def self.start(box_id)
    #load parameter
    g = Grader.new(box_id)

    #trying to connect to server, register as a new grader process

    # successfully connected, enter the loop
    g.main_loop
  end

  def self.run_job_with_id(job_id,box_id)
    g = Grader.new(box_id)
    g.job = Job.find(id)
    g.run_job
  end
end
