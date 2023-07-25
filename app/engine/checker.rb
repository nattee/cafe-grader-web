require 'open3'

class Checker
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  StdOutFilename = 'stdout.txt'
  StdErrFilename = 'stderr.txt'

  # check if required files, that are, output from submttion, answer from problem
  # and any other file is there
  def check_for_required_file
    raise RuntimeException.new "Output file not exists" unless @output_file.exist?
    raise RuntimeException.new "Answer file not exists" unless @ans_file.exist?
  end

  # main run function
  # run the submission against the testcase
  def process(sub,testcase)
    @sub = sub
    @testcase = testcase

    # init isolate
    # setup_isolate(@box_id)

    #prepare files location variable
    prepare_submission_directory(@sub)
    prepare_testcase_directory(@sub,@testcase)
    check_for_required_file

    cmd = "diff -b #{@output_file} #{@ans_file}"

    out,err,status = Open3.capture3(cmd)

    if (status.exitstatus == 0)
      judge_log "checking output of sub ##{@sub.id} testcase ##{@testcase.id}: 1 (correct)"
      return report_check_correct
    else
      judge_log "checking output of sub ##{@sub.id} testcase ##{@testcase.id}: 0 (wrong answer)"
      return report_check_wrong
    end

  end

  def report_check_correct(score = 1.to_d)
    {
      result: :correct,
      score: score
    }
  end

  def report_check_wrong(score = 0.to_d)
    {
      result: :wrong,
      score: score
    }
  end

  def report_check_partial(score)
    {
      result: :partial,
      score: score
    }
  end

  #return appropriate evaluator class for the submission
  def self.get_checker(submission)
    #TODO: should return appropriate scorer class
    return self
  end
end
