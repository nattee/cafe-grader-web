require 'pathname'
require 'net/http'

class Compiler
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers


  def validate
    raise GraderError.new("Sub ##{@sub.id} cannot find dataset ",
                          submission_id: @sub.id) unless @working_dataset
  end

  # main compile function
  def compile(sub,dataset)
    @sub = sub
    @working_dataset = dataset

    validate
    #init isolate
    setup_isolate(@box_id)

    #prepare source file
    prepare_submission_directory(@sub)
    prepare_files_for_compile

    #output file for compile
    compile_meta = @compile_result_path + Grader::COMPILE_RESULT_META_FILENAME
    compile_stdout_file = @compile_result_path + Grader::COMPILE_RESULT_STDOUT_FILENAME
    compile_stderr_file = @compile_result_path + Grader::COMPILE_RESULT_STDERR_FILENAME

    out,err,status,meta = cpp_compile(compile_meta)

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
      sub.update(status: :compilation_error,compiler_message: err,
                 points: nil, grader_comment: 'Compilation error',graded_at: Time.zone.now)
      return {status: :success, result_text: 'Compilation error', compile_result: :error}
    end
  end

  def prepare_files_for_compile
    #write student files
    File.write(@source_path + self.submission_filename,@sub.source)

    #write any manager files
    @working_dataset.managers.each do |mng|
      basename = mng.filename.base + mng.filename.extension_with_delimiter
      dest = @manager_path + basename

      mng.open do |tmpfile|
        FileUtils.move(tmpfile,dest)
        FileUtils.chmod(0666,dest)
      end
      # should we d/b as block??
      #File.open(dest,"w") do |fn|
      #  mng.open { |block| fn.write block }
      #end

    end
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

  def submission_filename
    @sub.problem.submission_filename || @sub.language.default_submission_filename
  end

  def self.get_compiler(sub)
    #TODO: should return appropriate compiler class
    case sub.language.name
    when 'cpp'
      return Compiler::CppCompiler
    when 'python'
      return Compiler::PythonCompiler
    else
      raise GraderError.new("Unsupported language (#{sub.language.name})",
                            submission_id: @sub.id)
    end
  end

end
