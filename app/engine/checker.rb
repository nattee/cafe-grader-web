require 'open3'

class Checker
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  # A language specific sub-class may override this method
  # it should return shell command that do the comparison
  def check_command(evaluation_type, input_file, output_file, ans_file)
    case evaluation_type
    when 'default'
      return "diff -q -b -B -Z #{output_file} #{ans_file}"
    when 'exact'
      return "diff -q #{output_file} #{ans_file}"
    when 'relative'
      prog = Rails.root.join 'lib', 'checker', (evaluation_type + ".rb")
      return "#{prog} #{input_file} #{output_file} #{ans_file}"
    when 'postgres'
      prog = Rails.root.join 'lib', 'checker', 'postgres_checker.rb'
      return "#{prog} #{input_file} #{output_file} #{ans_file}"
    when 'custom_cms'
      return "#{@prob_checker_file} #{input_file} #{output_file} #{ans_file}"
    when 'custom_cafe'
      return "#{@prob_checker_file} #{@sub.language.name} #{@testcase.num} #{input_file} #{output_file} #{ans_file} 10"
    when 'no_check'
      return ""
    end
  end

  def process_result_cms(out, err)
    score = out.chomp.strip
    err = err.chomp.strip
    err = nil if ['translate:success', 'translate:wrong'].include? err   # remove CMS default "translate:success" and "translate:wrong" from the comment
    err = nil if err.blank?
    return EngineResponse::CheckerResult.by_score(score: score, comment: err)
  end

  def process_result_cafe(out, err)
    arr = out.split("\n")
    if arr.count < 2
      return EngineResponse::CheckerResult.grader_error(comment: '(cafe-checker) output from checker is malformed')
    end
    score = arr[1].to_d/10
    if arr[0].upcase == "CORRECT"
      return EngineResponse::CheckerResult.correct(score: score)
    elsif arr[0].upcase == "INCORRECT"
      return EngineResponse::CheckerResult.wrong(score: score)
    elsif arr[0].split(':')[0].upcase == 'COMMENT'
      comment = arr[0][8...]
      return EngineResponse::CheckerResult.partial(score: score, comment: comment)
    else
      return EngineResponse::CheckerResult.grader_error(comment: '(cafe-checker) output from checker is malformed')
    end
  end

  def process_result(evaluation_type, out, err, status)
    case evaluation_type
    when 'default', 'exact', 'relative'
      # these standard check return 0 when correct
      if status.exitstatus == 0
        return EngineResponse::CheckerResult.correct
      else
        return EngineResponse::CheckerResult.wrong
      end
    when 'postgres'
      return process_result_cms(out, err)
    when 'custom_cms', 'custom_cafe'
      if status.exitstatus == 0
        if evaluation_type == 'custom_cms'
          return process_result_cms(out, err)
        else
          return process_result_cafe(out, err)
        end
      else
        comment = "ERROR IN CHECKER!!!\n-- stderr --\n#{err}-- status -- #{status}"
        return EngineResponse::CheckerResult.grader_error(comment: comment)
      end
    when 'no_check'
      return EngineResponse::CheckerResult.partial(score: 0)
    else
      return EngineResponse::CheckerResult.grader_error(comment: 'Unknown evaluation type')
    end
  end

  # check if required files, that are, output from submttion, answer from problem
  # and any other file is there
  def check_for_required_file
    raise "Output file [#{@output_file.cleanpath}] does not exists" unless @output_file.exist?
    raise "Answer file [#{@ans_file.cleanpath}] does not exists" unless @ans_file.exist?
    if ['custom_cms', 'custom_cafe'].include?(@ds.evaluation_type) &&
        (@prob_checker_file.nil? || @prob_checker_file.exist? == false)
      raise GraderError.new("Checker file does not exists", submission_id: @sub.id)
    end
  end

  def result_status_with_color(result)
    if result[:result] == :correct
      color = COLOR_GRADING_CORRECT
    elsif result[:result] == :wrong
      color = COLOR_GRADING_WRONG
    elsif result[:result] == :partial
      color = COLOR_GRADING_PARTIAL
    else
      color = :red
    end

    res = Rainbow(result[:result].to_s).color(color)
    res += " comment: #{result[:comment]}" unless result[:comment].blank?
    return res
  end

  # main run function
  # run the submission against the testcase
  def process(sub, testcase)
    @sub = sub
    @testcase = testcase
    @ds = @testcase.dataset

    # init isolate
    # setup_isolate(@box_id)

    # prepare files location variable
    prepare_submission_directory(@sub)
    prepare_dataset_directory(@ds)
    prepare_testcase_directory(@sub, @testcase)
    check_for_required_file

    cmd = check_command(@ds.evaluation_type, @input_file, @output_file, @ans_file)

    # call the compare command
    judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} check cmd: " + Rainbow(cmd).color(JudgeBase::COLOR_CHECK_CMD)
    out, err, status = Open3.capture3(cmd)

    result = process_result(@ds.evaluation_type, out, err, status)
    judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} check result: "+result_status_with_color(result)
    return result
  end

  # return appropriate evaluator class for the submission
  def self.get_checker(submission)
    # TODO: should return appropriate scorer class
    return self
  end
end
