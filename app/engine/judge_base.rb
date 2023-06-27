module JudgeBase
  InputFilename = 'input.txt'
  AnsFilename = 'answer.txt'

  def initialize(box_id,host_id)
    @box_id = box_id
    @host_id = host_id

    puts "Create #{self.class.to_s} with box_id = #{box_id}, host_id = #{host_id}"
  end

  def prepare_submission_directory
    #preparing path name
    @submission_path = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeSubmissionPath + @sub.id.to_s
    @bin_path = @submission_path + Grader::JudgeSubmissionBinPath
    @source_path = @submission_path + Grader::JudgeSubmissionSourcePath
    @lib_path = @submission_path + Grader::JudgeSubmissionLibPath

    #prepare folder
    @bin_path.mkpath
    @bin_path.chmod(0777)
    @source_path.mkpath
    @lib_path.mkpath

  end

  def prepare_testcase_directory
    #preparing path name
    @problem_path = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeProblemPath + @sub.problem.id.to_s
    @prob_testcase_path = @problem_path + @testcase.id.to_s
    @sub_testcase_path = @submission_path + @testcase.get_name_for_dir
    @output_path = @sub_testcase_path + 'output'
    @input_path = @prob_testcase_path + 'input' #we need additional dir because we will mount this dir to the isolate
    @input_file = @input_path + InputFilename
    @ans_file = @prob_testcase_path + AnsFilename

    #prepare folder
    @prob_testcase_path.mkpath
    @sub_testcase_path.mkpath
    @input_path.mkpath
    @output_path.mkpath

  end
end
