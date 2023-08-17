class Compiler::CppCompiler < Compiler
  def compile(meta_file)
    #prepare params for running sandbox
    args = %w(-O2 -s -std=c++17 -static -DCONTEST -lm -Wall)          # options
    args << "-iquote /source -iquote /source_manager"
    args << "-o /bin/#{@sub.problem.exec_filename(@sub.language)}"    # output file

    # add main files
    if @sub.problem.self_contained?
      args << "/source/#{self.submission_filename}"                               # the source code
    else
      args << "/source_manager/#{@working_dataset.main_filename}"               # the source code
    end

    cmd = ["#{Rails.configuration.worker[:compiler][:cpp]}"]
    cmd += args
    cmd_string = cmd.join ' '

    #run the compilation in the isolated environment
    isolate_args = %w(-p -E PATH)
    output = {"/bin":@compile_path.cleanpath}
    input = {"/source":@source_path.cleanpath, "/source_manager":@manager_path.cleanpath}
    return run_isolate(cmd_string,time_limit: 10, input: input, output: output, isolate_args: isolate_args, meta: meta_file)
  end


end
