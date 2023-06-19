class Evaluator
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers


  # main evaluation function
  def evaluate(box_id,sub,testcase)
    @sub = sub
    @testcase = testcase

    #init isolate
    setup_isolate(box_id)

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
    File.write(@output_path + 'stdout.txt',out)
    File.write(@output_path + 'stderr.txt',err)
  end

  def prepare_executable
    #check if the file is ready
    return if File.exist? @bin_path + 'bin_ready'

    #if not, check if some other process from our host is preparing the file

    #if no one is preparing, acquire the lock and prepare the file
    GraderProcess.transaction do
      @sub.compiled_files.each do |attachment|
        filename = @bin_path + attachment.filename.to_s
        File.open(filename,'w:ASCII-8BIT'){ |f| attachment.download { |x| f.write x} }
        FileUtils.chmod('a+x',filename)
      end
      FileUtils.touch(@bin_path + 'bin_ready')
    end
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

  def self.get_evaluator(sub)
    #TODO: should return appropriate compiler class
    return self
  end
end
