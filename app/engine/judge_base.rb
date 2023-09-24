module JudgeBase
  INPUT_FILENAME = 'input.txt'
  STDOUT_FILENAME = 'stdout.txt'
  StdErrFilename = 'stderr.txt'
  AnsFilename = 'answer.txt'

  COMPILE_RESULT_STDOUT_FILENAME = 'compile_output'
  COMPILE_RESULT_STDERR_FILENAME = 'compile_err'
  COMPILE_RESULT_META_FILENAME = 'compile_meta'

  ISOLATE_BIN_PATH = 'mybin'
  ISOLATE_SOURCE_PATH = 'source'
  ISOLATE_SOURCE_MANAGER_PATH = 'source_manager'
  ISOLATE_INPUT_PATH = 'input'
  ISOLATE_OUTPUT_PATH = 'output'

  #color for Rainbow
  COLOR_SUB = :skyblue
  COLOR_TESTCASE = :salmon
  COLOR_PROB = :deepink
  COLOR_COMPILE_SUCCESS = :lawngreen
  COLOR_COMPILE_ERROR = :deeppink
  COLOR_EVALUATION_DONE = :yellowgreen
  COLOR_EVALUATION_FORCE_EXIT = :orangered
  COLOR_GRADING_CORRECT = :seagreen
  COLOR_GRADING_WRONG = :crimson
  COLOR_SCORE_RESULT = :orange
  COLOR_ERROR = :darkred



  def initialize(worker_id,box_id)
    @worker_id = worker_id
    @box_id = box_id

    judge_log "#{self.class.to_s} created"
  end

  def isolate_need_cg_by_lang(language_name)
    case language_name
    when 'java', 'digital'
      true
    else
      false
    end
  end

  # additional options for isolate for each language
  def isolate_options_by_lang(language_name)
    case language_name
    when 'java'
      '-p -d /etc/alternatives'
    when 'digital'
      "-p -d /etc -d /tmp:rw -d /my_lib=#{Pathname.new(Rails.configuration.worker[:compiler][:digital]).dirname}"
    when 'rust'
      '-p -d /etc/alternatives'
    else
      ''
    end
  end

  # return true when we must redirect the input into stdin
  def input_redirect_by_lang(language_name)
    case language_name
    when 'digital'
      return false
    else
      return true
    end
  end

  # set up directory and path/filename of the submission directory
  def prepare_submission_directory(sub)
    #preparing path name
    @submission_path = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeSubmissionPath + sub.id.to_s
    @compile_path = @submission_path + Grader::JudgeSubmissionCompilePath
    @compile_result_path = @submission_path + Grader::JUDGE_SUB_COMPILE_RESULT_PATH
    @bin_path = @submission_path + Grader::JudgeSubmissionBinPath
    @source_path = @submission_path + Grader::JudgeSubmissionSourcePath
    @manager_path = @submission_path + Grader::JUDGE_MANAGER_PATH
    @lib_path = @submission_path + Grader::JudgeSubmissionLibPath

    #prepare folder
    @compile_path.mkpath
    @compile_path.chmod(0777)
    @compile_result_path.mkpath
    @bin_path.mkpath
    @bin_path.chmod(0777)
    @source_path.mkpath
    @manager_path.mkpath
    @lib_path.mkpath

    #prepare path name inside isolate
    @isolate_bin_path = Pathname.new('/'+ISOLATE_BIN_PATH)
    @isolate_source_path = Pathname.new('/'+ISOLATE_SOURCE_PATH)
    @isolate_source_manager_path = Pathname.new('/'+ISOLATE_SOURCE_MANAGER_PATH)
    @isolate_input_path = Pathname.new('/'+ISOLATE_INPUT_PATH)
    @isolate_input_file = @isolate_input_path + INPUT_FILENAME
    @isolate_output_path = Pathname.new('/'+ISOLATE_OUTPUT_PATH)
    @isolate_stdout_file = @isolate_output_path + STDOUT_FILENAME
  end

  # set up directory and path/filename of the testcase directory
  def prepare_testcase_directory(sub,testcase)
    #preparing path name
    @problem_path = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeProblemPath + sub.problem.id.to_s
    @prob_testcase_path = @problem_path + testcase.id.to_s
    @sub_testcase_path = @submission_path + testcase.get_name_for_dir
    @output_path = @sub_testcase_path + 'output'
    @output_file = @output_path + STDOUT_FILENAME
    @input_path = @prob_testcase_path + 'input' #we need additional dir because we will mount this dir to the isolate
    @input_file = @input_path + INPUT_FILENAME
    @ans_file = @prob_testcase_path + AnsFilename

    #prepare folder
    @prob_testcase_path.mkpath
    @sub_testcase_path.mkpath
    @input_path.mkpath
    @output_path.mkpath

    @output_path.chmod(0777)
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

  def test_log(keyword)
    n = 1_000_000
    n.times do |i|
      judge_log "#{keyword} test " + i.to_s
    end
  end

  # -------------- coloring with rainbow ----------------
  def rb_sub(sub)
    Rainbow('#'+sub.id.to_s).color(COLOR_SUB)
  end

  def rb_prob(prob)
    Rainbow(prob.id).color(COLOR_PROB)
  end

  def rb_testcase(testcase)
    Rainbow(testcase.id).color(COLOR_TESTCASE)
  end

end
