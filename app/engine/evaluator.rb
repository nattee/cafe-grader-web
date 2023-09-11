class Evaluator
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  # main run function
  # run the submission against the testcase
  def execute(sub,testcase)
    @sub = sub
    @testcase = testcase
    @working_dataset = @testcase.dataset

    #init isolate
    setup_isolate(@box_id, isolate_need_cg_by_lang(@sub.language.name))

    #prepare data files
    prepare_submission_directory(@sub)
    prepare_testcase_files
    prepare_testcase_directory(@sub, @testcase) # !!! MUST BE CALLED AFTER prepare_testcase_files
    prepare_executable

    #prepare params for running sandbox
    executable = @isolate_bin_path + @sub.problem.exec_filename(@sub.language)
    cmd = [executable]
    cmd_string = cmd.join ' '

    #run the evaluation in the isolated environment
    isolate_args = %w(-E PATH)
    isolate_args << isolate_options_by_lang(@sub.language.name)
    isolate_args += ["-i","#{@isolate_input_file}"] if input_redirect_by_lang(@sub.language.name)
    input = {"#{@isolate_input_path}":@input_file.dirname, "#{@isolate_bin_path}":@mybin_path.cleanpath}
    meta_file = @output_path + 'meta.txt'

    out,err,status,meta = run_isolate(cmd_string,input: input, isolate_args: isolate_args,meta: meta_file,
                                      time_limit: @working_dataset.time_limit,mem_limit: @working_dataset.memory_limit,
                                      cg: isolate_need_cg_by_lang(@sub.language.name))
    #clean up isolate
    cleanup_isolate

    #save result to disk
    stdout_file = @output_path + StdOutFilename
    stderr_file = @output_path + StdErrFilename
    File.write(stdout_file,out)
    File.write(stderr_file,err)

    #call evaluate to check the result
    result = evaluate(out,meta,err)
    return result
  end

  # this should be called after execute, it will runs the comparator
  def evaluate(out,meta,err)
    result = default_success_result("evaluation completed successfully")
    e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase)

    # any error?
    unless meta['status'].blank?
      time = meta['time'] || meta['time-wall'] || 0
      if meta['status'] == 'SG'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'],result: :crash)
      elsif meta['status'] == 'TO'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :time_limit)
      elsif meta['status'] == 'RE'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :crash)
      elsif meta['status'] == 'XX'
        e.update(isolate_message: meta['message'], result: :grader_error)
      else
        #other status
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :unknown_error)
      end
      judge_log "##{@sub.id} Testcase: #{@testcase.id} forced exit by isolate (#{meta['status']}) #{err}"
    else
      judge_log "##{@sub.id} Testcase: #{@testcase.id} ends normally"
      #ends normally, runs the comparator
      checker = Checker.get_checker(@sub).new(@worker_id, @box_id)
      check_result = checker.process(@sub,@testcase)
      e.update( time: meta['time'] * 1000,memory: meta['max-rss'],
                result: check_result[:result], score: check_result[:score])
    end

    #save final result
    e.set_result_text_from_result
    return result;
  end

  def prepare_executable
    @mybin_path = @bin_path + @box_id.to_s
    @mybin_path.mkpath

    @sub.compiled_files.each do |attachment|
      filename = @mybin_path + attachment.filename.to_s
      unless filename.exist?
        File.open(filename,'w:ASCII-8BIT'){ |f| attachment.download { |x| f.write x} } 
        judge_log "Downloaded executable #{filename}"
      end
      FileUtils.chmod('a+x',filename)
    end
  end

  def prepare_testcase_files
    # lock problem for this worker
    WorkerDataset.transaction do
      wp = WorkerDataset.lock("FOR UPDATE").find_or_create_by(worker_id: @worker_id, dataset_id: @working_dataset.id)
      if wp.status == 'created'
        # no one is working on this worker problem, I will download
        wp.update(status: :downloading_testcase)

        #download all testcase
        @working_dataset.testcases.each do |tc|
          prepare_testcase_directory(@sub,tc)

          #download testcase
          File.write(@input_file,tc.input)
          File.write(@ans_file,tc.sol)

          #do the symlink
          #testcase codename inside prob_id/testcase_id
          FileUtils.touch(@prob_testcase_path + tc.get_name_for_dir)

          #dataset_id/testcase_codename (symlink to prob_id/testcase_id)
          ds_dir = @problem_path + ('dsid_'+tc.dataset.id.to_s)
          ds_dir.mkpath
          ds_ts_codename_dir = ds_dir + tc.get_name_for_dir
          ds_codename_dir = @problem_path + ('dsname_'+tc.dataset.get_name_for_dir)
          FileUtils.symlink(@prob_testcase_path, ds_ts_codename_dir) unless File.exist? ds_ts_codename_dir.cleanpath
          FileUtils.symlink(ds_dir, ds_codename_dir) unless File.exist? ds_codename_dir.cleanpath

          judge_log("Testcase #{tc.id} (#{tc.code_name}) downloaded")
        end

        # if any lib, dl as well

        # if any manager

        # tell other that we are ready
        wp.update(status: :ready)
      elsif wp.status == 'ready'
        judge_log("Found downloaded testcase")
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
