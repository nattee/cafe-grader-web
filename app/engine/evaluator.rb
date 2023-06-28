class Evaluator
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  StdOutFilename = 'stdout.txt'
  StdErrFilename = 'stderr.txt'



  # main run function
  # run the submission against the testcase
  def execute(sub,testcase)
    @sub = sub
    @testcase = testcase

    #init isolate
    setup_isolate(@box_id)

    #prepare data files
    prepare_submission_directory
    prepare_testcase_directory
    prepare_files_for_evaluate

    #prepare params for running sandbox
    executable = '/mybin/' + @sub.problem.exec_filename(@sub.language)
    cmd = [executable]
    cmd_string = cmd.join ' '

    #run the evaluation in the isolated environment
    isolate_args = %w(-p -E PATH)
    isolate_args += %w(-i /input/input.txt)
    input = {"/input":@input_file.dirname, "/mybin":@bin_path.cleanpath}
    puts "CMD: #{cmd_string}"
    out,err,status = run_isolate(cmd_string,input: input, isolate_args: isolate_args)

    #save result to disk
    File.write(@output_path + StdOutFilename,out)
    File.write(@output_path + StdErrFilename,err)

    #call evaluate to check the result
    evaluate(out,err)

  end

  # this should be called after execute
  def evaluate(out,err)
    #check for result
    result = parse_isolate_result(err)


  end

  # return a hash {result: result_code, time: runtime}
  def parse_isolate_result(text)
    if text[0...2] == 'OK'
      md = text.match /OK \((\d+\.\d+) sec real/
      return {result: 0, time: md[1].to_d}
    elsif text[0...2] == 'TO'
    else
    end

  end

  def prepare_executable
    result = false

    #check if some other process from our host is preparing the file
    HostProblem.transaction do
      hp = HostProblem.lock("FOR UPDATE").find_or_create_by(host_id: @host_id, problem_id: @sub.problem.id)
      result = hp.executable_ready?
      unless result
        #execute table is not downloaded, do so.
        @sub.compiled_files.each do |attachment|
          filename = @bin_path + attachment.filename.to_s
          File.open(filename,'w:ASCII-8BIT'){ |f| attachment.download { |x| f.write x} }
          FileUtils.chmod('a+x',filename)
        end

        #report and commit the transaction
        FileUtils.touch(@bin_path + 'bin_ready')
        hp.update(executable_ready: true)
        result = true
      end
    end
    return result
  end

  def prepare_files_for_evaluate
    prepare_executable

    #write input/ans files
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
  end

  #return appropriate evaluator class for the submission
  def self.get_evaluator(submission)
    #TODO: should return appropriate compiler class
    return self
  end
end
