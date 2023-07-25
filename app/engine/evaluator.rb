class Evaluator
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers




  # main run function
  # run the submission against the testcase
  def execute(sub,testcase)
    @sub = sub
    @testcase = testcase

    #init isolate
    setup_isolate(@box_id)

    #prepare data files
    prepare_submission_directory(@sub)
    prepare_testcase_directory(@sub,@testcase)
    prepare_testcase_files
    prepare_executable

    #prepare params for running sandbox
    executable = '/mybin/' + @sub.problem.exec_filename(@sub.language)
    cmd = [executable]
    cmd_string = cmd.join ' '

    #run the evaluation in the isolated environment
    isolate_args = %w(-p -E PATH)
    isolate_args += %w(-i /input/input.txt)
    input = {"/input":@input_file.dirname, "/mybin":@bin_path.cleanpath}
    meta_file = @output_path + 'meta.txt'

    out,err,status,meta = run_isolate(cmd_string,input: input, isolate_args: isolate_args,meta: meta_file)

    #save result to disk
    File.write(@output_path + StdOutFilename,out)
    File.write(@output_path + StdErrFilename,err)

    #call evaluate to check the result
    result = evaluate(out,meta)
    return result
  end

  # this should be called after execute, it will runs the comparator
  def evaluate(out,meta)
    result = default_success_result("evaluation completed successfully")
    unless meta['status'].blank?
      if meta['status'] == 'SG'
        e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase).update(
                          time: meta['time'] * 1000, memory: meta['max-rss'], message: meta['message'],result: :crash)
      elsif meta['status'] == 'TO'
        e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase).update(
                          time: meta['time-wall'] * 1000, memory: meta['max-rss'], message: meta['message'], result: :time_limit)
      else
        e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase).update(
                          time: meta['time'] * 1000, memory: meta['max-rss'], message: meta['message'], result: :unknown_error)
        #other status
      end
    else
      #ends normally, runs the comparator
      checker = Checker.get_checker(@sub).new(@host_id, @box_id)
      check_result = checker.process(@sub,@testcase)
      e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase).update(
                        time: meta['time'] * 1000,memory: meta['max-rss'],
                        result: check_result[:result], score: check_result[:score])
    end
    return result;
  end

  def prepare_executable
    @sub.compiled_files.each do |attachment|
      filename = @bin_path + attachment.filename.to_s
      unless filename.exist?
        File.open(filename,'w:ASCII-8BIT'){ |f| attachment.download { |x| f.write x} } 
        judge_log "Downloaded executable #{filename}"
      end
      FileUtils.chmod('a+x',filename)
    end
  end

  def prepare_testcase_files
    # lock problem for this host
    HostProblem.transaction do
      hp = HostProblem.lock("FOR UPDATE").find_or_create_by(host_id: @host_id, problem_id: @sub.problem.id)
      if hp.status == 'created'
        # no one is working on this host problem, I will download
        hp.update(status: :downloading_testcase)

        #download all testcase
        @sub.data_set.testcases.each do |tc|
          prepare_testcase_directory(@sub,tc)

          #download testcase
          File.write(@input_file,@testcase.input)
          File.write(@ans_file,@testcase.sol)

          #do the symlink
          #testcase codename inside prob_id/testcase_id
          FileUtils.touch(@prob_testcase_path + @testcase.get_name_for_dir)

          #data_set_id/testcase_codename (symlink to prob_id/testcase_id)
          ds_dir = @problem_path + ('dsid_'+@testcase.data_set.id.to_s)
          ds_dir.mkpath
          ds_ts_codename_dir = ds_dir + @testcase.get_name_for_dir
          ds_codename_dir = @problem_path + ('dsname_'+@testcase.data_set.get_name_for_dir)
          FileUtils.symlink(@prob_testcase_path, ds_ts_codename_dir) unless File.exist? ds_ts_codename_dir.cleanpath
          FileUtils.symlink(ds_dir, ds_codename_dir) unless File.exist? ds_codename_dir.cleanpath

          judge_log("Testcase #{tc.id} (#{tc.code_name}) downloaded")
        end

        # if any lib, dl as well

        # if any manager

        # tell other that we are ready
        hp.update(status: :ready)
      elsif hp.status == 'ready'
        judge_log("Testcases already exists")
      else
        # status should be ready, if it stuck at :downloading, the program will stuck
      end
    end
    return default_success_result

  end


  #return appropriate evaluator class for the submission
  def self.get_evaluator(submission)
    #TODO: should return appropriate compiler class
    return self
  end
end
