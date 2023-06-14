class Grader
  # This class is the main event loop for grader process
  # It is associated with one box-id of isolate
  # Responsible for dispatching a job

  JudgeResultPath = 'isolate_result'
  JudgeResultBinPath = 'bin'
  JudgeResultSourcePath = 'source'
  JudgeResultLibPath = 'lib'

  attr_accessor :job
  attr_reader :box_id

  def initialize(box_id)
    @box_id = box_id
  end

  def process_job_compile
    sub = Submission.find(job.arg)
    compiler = Compile.get_compiler(sub)
    compiler.compile(sub)
  end

  def run_job
    if @job.job_type == :compile
      process_job_compile
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
