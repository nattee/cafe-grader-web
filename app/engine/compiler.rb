require 'pathname'
require 'net/http'

class Compiler
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  SourceFilename = 'source.cpp'

  # main compile function
  def compile(sub)
    @sub = sub
    #init isolate
    setup_isolate(@box_id)

    #prepare source file
    prepare_submission_directory(@sub)
    prepare_files_for_compile

    #prepare params for running sandbox
    args = %w(-O2 -s -std=c++17 -static -DCONTEST -lm -Wall)          # options
    args << "-o /bin/#{@sub.problem.exec_filename(@sub.language)}"    # output file
    args << "/source/#{SourceFilename}"                               # the source code
    cmd = ["#{Rails.configuration.worker[:compiler][:cpp]}"]
    cmd += args
    cmd_string = cmd.join ' '

    #output file
    compile_meta = @compile_result_path + Grader::COMPILE_RESULT_META_FILENAME
    compile_stdout_file = @compile_result_path + Grader::COMPILE_RESULT_STDOUT_FILENAME
    compile_stderr_file = @compile_result_path + Grader::COMPILE_RESULT_STDERR_FILENAME

    #run the compilation in the isolated environment
    isolate_args = %w(-p -E PATH)
    output = {"/bin":@compile_path.cleanpath}
    input = {"/source":@source_path.cleanpath}
    out,err,status,meta = run_isolate(cmd_string,input: input, output: output, isolate_args: isolate_args, meta: compile_meta)

    #save result
    File.write(compile_stdout_file,out)
    File.write(compile_stderr_file,err)

    #clean up isolate
    cleanup_isolate

    if meta['exitcode'] == 0
      # the result should be at @bin_path
      upload_compiled_files
      sub.update(status: :compilation_success,compiler_message: out)
      return {status: :success, result_text: 'Compiled successfully', compile_result: :success}
    else
      # error in compilation
      sub.update(status: :compilation_error,compiler_message: err)
      return {status: :success, result_text: 'Compilation error', compile_result: :error}
    end
  end

  def prepare_files_for_compile
    #copy required file
    File.write(@source_path + SourceFilename,@sub.source)
  end

  def upload_compiled_files
    uri = URI('http://'+Rails.configuration.worker[:hosts][:web]+worker_compiled_submission_path(@sub))
    hostname = uri.hostname
    port = uri.port

    req = Net::HTTP::Post.new(uri) # => #<Net::HTTP::Post POST>
    form_data = []

    #load files
    Dir.glob(@compile_path + '*').each do |fn|
      form_data << ['compiled_files',File.open(fn)]
    end

    #POST
    req.set_form form_data, 'multipart/form-data'
    res = Net::HTTP.start(hostname,port) do |http|
      http.request(req)
    end
  end

  def self.get_compiler(sub)
    #TODO: should return appropriate compiler class
    return self
  end

end
