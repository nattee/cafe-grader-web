module JudgeBase
  InputFilename = 'input.txt'
  StdOutFilename = 'stdout.txt'
  StdErrFilename = 'stderr.txt'
  AnsFilename = 'answer.txt'


  def initialize(worker_id,box_id)
    @worker_id = worker_id
    @box_id = box_id

    judge_log "#{self.class.to_s} created"
  end

  # set up directory and path/filename of the submission directory
  def prepare_submission_directory(sub)
    #preparing path name
    @submission_path = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeSubmissionPath + sub.id.to_s
    @compile_path = @submission_path + Grader::JudgeSubmissionCompilePath
    @bin_path = @submission_path + Grader::JudgeSubmissionBinPath + "#{@box_id}"
    @source_path = @submission_path + Grader::JudgeSubmissionSourcePath
    @lib_path = @submission_path + Grader::JudgeSubmissionLibPath

    #prepare folder
    @compile_path.mkpath
    @compile_path.chmod(0777)
    @bin_path.mkpath
    @bin_path.chmod(0777)
    @source_path.mkpath
    @lib_path.mkpath
  end

  # set up directory and path/filename of the testcase directory
  def prepare_testcase_directory(sub,testcase)
    #preparing path name
    @problem_path = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeProblemPath + sub.problem.id.to_s
    @prob_testcase_path = @problem_path + testcase.id.to_s
    @sub_testcase_path = @submission_path + testcase.get_name_for_dir
    @output_path = @sub_testcase_path + 'output'
    @output_file = @output_path + StdOutFilename
    @input_path = @prob_testcase_path + 'input' #we need additional dir because we will mount this dir to the isolate
    @input_file = @input_path + InputFilename
    @ans_file = @prob_testcase_path + AnsFilename

    #prepare folder
    @prob_testcase_path.mkpath
    @sub_testcase_path.mkpath
    @input_path.mkpath
    @output_path.mkpath
  end


  def build_result_hash
    {status: nil,
     result_text: nil
    }
  end

  def default_success_result(msg = nil)
    {status: :success, result_text: msg}
  end

  def judge_log(msg,severity = Logger::INFO)
    JudgeLogger.logger.add(severity,msg,judge_log_tag)
  end

  def judge_log_tag
    "Worker: #{@worker_id}, Box: #{@box_id} (#{self.class.name})"
  end

end
