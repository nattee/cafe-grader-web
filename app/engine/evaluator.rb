require 'net/http'

# This class runs the submission against a given testcases
# It also runs the checker on the output produced by the submission
# There are two mains method *execute* which runs the sub and *evaluate*
# which compare the output

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
    prepare_dataset_directory(@working_dataset)
    prepare_worker_dataset(@working_dataset,:all)
    prepare_testcase_directory(@sub, @testcase)
    prepare_executable

    #prepare params for running sandbox
    executable = @isolate_bin_path + @sub.problem.exec_filename(@sub.language)
    cmd = [executable,testcase.id]
    cmd_string = cmd.join ' '

    #run the evaluation in the isolated environment
    isolate_args = %w(-E PATH)
    isolate_args << isolate_options_by_lang(@sub.language.name)
    isolate_args += ["-o","#{@isolate_stdout_file}"] #redirect program stdout to @isolate_stdout_file
    isolate_args += ['--stderr-to-stdout'] if input_redirect_by_lang(@sub.language.name)  # also redirect stderr, if needed
    isolate_args += ["-i","#{@isolate_input_file}"] if input_redirect_by_lang(@sub.language.name) #redirect input, if needed
    isolate_args += ['-f 50000'] # allow max 50MB output
    input = {"#{@isolate_input_path}":@input_file.dirname,
             "#{@isolate_data_path}":@prob_data_path.cleanpath,
             "#{@isolate_bin_path}":@mybin_path.cleanpath}
    output = {"#{@isolate_output_path}":@output_path}
    meta_file = @sub_testcase_path + 'meta.txt'

    out,err,status,meta = run_isolate(cmd_string,input: input, output: output, isolate_args: isolate_args,meta: meta_file,
                                  time_limit: @working_dataset.time_limit,mem_limit: @working_dataset.memory_limit,
                                  cg: isolate_need_cg_by_lang(@sub.language.name))

    # also run isolate to chmod the outputfile
    run_isolate('/usr/bin/chmod 0777 '+@isolate_stdout_file.to_s,output: output, meta: nil)

    #clean up isolate
    cleanup_isolate

    #there should be nothing in "out" because we redirect it by -o
    #save isolate's stderr to disk
    stderr_file = @sub_testcase_path + StdErrFilename
    File.write(stderr_file,err)

    #call evaluate to check the result
    result = evaluate(out,meta,err)
    return result
  end

  # this should be called after execute, it will runs the comparator
  def evaluate(out,meta,err)
    judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} checking execution result..."
    result = default_success_result("evaluation completed successfully")
    e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase)

    # any error?
    unless meta['status'].blank?
      judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} forced exit by isolate (#{Rainbow(meta['status']).color(COLOR_EVALUATION_FORCE_EXIT)}) #{Rainbow(err).color(COLOR_EVALUATION_FORCE_EXIT)} "
      time = meta['time'] || meta['time-wall'] || 0
      if meta['status'] == 'SG'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'],result: :crash)
      elsif meta['status'] == 'TO'
        e.update(time: meta['time-wall'] * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :time_limit)
      elsif meta['status'] == 'RE'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :crash)
      elsif meta['status'] == 'XX'
        e.update(isolate_message: meta['message'], result: :grader_error)
      else
        #other status
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :unknown_error)
      end
    else
      judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} ends normally"
      #ends normally, runs the comparator
      checker = Checker.get_checker(@sub).new(@worker_id, @box_id)
      check_result = checker.process(@sub,@testcase)
      e.update( time: meta['time'] * 1000,memory: meta['max-rss'],
                result: check_result[:result], score: check_result[:score])
    end

    #save final result
    e.set_result_text_from_result
    judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} Evaluation #{Rainbow('done').color(COLOR_EVALUATION_DONE)}"
    return result;
  end

  def prepare_executable
    @mybin_path = @bin_path + @box_id.to_s
    @mybin_path.mkpath

    # download each compiled files
    @sub.compiled_files.each do |attachment|
      filename = @mybin_path + attachment.filename.to_s

      #download from server
      url = Rails.configuration.worker[:hosts][:web]+worker_get_compiled_submission_path(@sub,attachment.id)
      begin
        download_from_web(url,filename,download_type: 'executable',chmod_mode: 'a+x')
      rescue Net::HTTPExceptions => he
        raise GraderError.new("Error download compiled file \"#{he}\"",submission_id: @sub.id )
      end
      FileUtils.chmod('a+x',filename)
    end

  end


  #return appropriate evaluator class for the submission
  def self.get_evaluator(submission)
    #TODO: should return appropriate compiler class
    return self
  end
end
