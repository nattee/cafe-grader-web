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

  # Each langauge specific sub-class MUST implement this method
  # it should return shell command that do the compilation
  def build_compile_command(isolate_source, isolate_bin)
  end

  # Each langauge specific sub-class MAY implement this method
  # it will be run BEFORE a compilation is success
  # normal use case is for java when we have to detect the classname of the file
  def pre_compile
  end

  # Each langauge specific sub-class MAY implement this method
  # it will be run after a compilation is success
  # normal use case is for scripting language
  # where compilation is actually linting and
  # post compile is to modify the source by adding shebang
  # or add a script
  def post_compile
  end

  # Each langauge specific sub-class MAY override this method
  # This should return {success: true, compiler_message: xxx}
  #   out = stdout
  #   err = stderr
  #   status = status text from isolate
  #   meta = meta object from isolate
  def check_compile_result(out,err,status,meta)
    if meta['exitcode'] == 0
      #compiler finished successfully
      return {success: true, compiler_message: out}
    else
      #compiler found some error
      return {success: false, compiler_message: err}
    end
  end

  # main compile function
  def compile(sub,dataset)
    @sub = sub
    @working_dataset = dataset

    validate
    #init isolate
    setup_isolate(@box_id, isolate_need_cg_by_lang(@sub.language.name))

    #prepare source file
    prepare_submission_directory(@sub)
    prepare_files_for_compile

    #running any precompile script
    @exec_file = @compile_path + @sub.problem.exec_filename(@sub.language)
    pre_compile

    # ------ run the compilation ------
    #output file
    compile_meta = @compile_result_path + Grader::COMPILE_RESULT_META_FILENAME
    compile_stdout_file = @compile_result_path + Grader::COMPILE_RESULT_STDOUT_FILENAME
    compile_stderr_file = @compile_result_path + Grader::COMPILE_RESULT_STDERR_FILENAME

    # isolate filename for source to be compiled (considering self_contain? or task's main file)
    isolate_source_file = @sub.problem.self_contained? ?
      @isolate_source_file :
      @isolate_main_file

    # isolate pathname for executable after compiled
    isolate_bin_file = @isolate_bin_path + @sub.problem.exec_filename(@sub.language)

    #calling language specific method to get cmd for compiling
    cmd_string = build_compile_command(isolate_source_file,isolate_bin_file)

    # prepare params for isolate
    isolate_args = %w(-p -E PATH)
    isolate_args << isolate_options_by_lang(@sub.language.name)
    output = { "#{@isolate_bin_path}": @compile_path.cleanpath}
    input = {"#{@isolate_source_path}": @source_path.cleanpath, "/source_manager":@manager_path.cleanpath}
    out,err,status,meta = run_isolate(cmd_string,
                       time_limit: 10,
                       input: input,
                       output: output,
                       isolate_args: isolate_args,
                       meta: compile_meta,
                       cg: isolate_need_cg_by_lang(@sub.language.name))

    #save result
    File.write(compile_stdout_file,out)
    File.write(compile_stderr_file,err)

    #clean up isolate
    cleanup_isolate

    # call language-specific checking of compilation
    compile_result = check_compile_result(out,err,status,meta)

    if compile_result[:success]
      #run any post compilation
      post_compile

      # the result should be at @bin_path
      upload_compiled_files
      sub.update(status: :compilation_success,compiler_message: compile_result[:compiler_message])
      return {status: :success, result_text: 'Compiled successfully', compile_result: :success}
    else
      # error in compilation
      sub.update(status: :compilation_error,compiler_message: compile_result[:compiler_message],
                 points: nil, grader_comment: 'Compilation error',graded_at: Time.zone.now)
      return {status: :success, result_text: 'Compilation error', compile_result: :error}
    end
  end

  def prepare_files_for_compile
    #setup pathname
    @source_file = @source_path + self.submission_filename;
    @source_main_file = @manager_path + (@working_dataset.main_filename || '')
    @isolate_source_file = @isolate_source_path + self.submission_filename;
    @isolate_main_file = @isolate_source_manager_path + (@working_dataset.main_filename || '')

    #write student files
    File.write(@source_file.cleanpath,@sub.source)

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
    uri = URI(Rails.configuration.worker[:hosts][:web]+worker_compiled_submission_path(@sub))
    hostname = uri.hostname
    port = uri.port

    req = Net::HTTP::Post.new(uri) # => #<Net::HTTP::Post POST>
    files = []


    #load files
    Dir.glob(@compile_path + '*').each do |fn|
      files << ['compiled_files[]',File.open(fn)]
      judge_log "Bundling compiled files #{fn}"
    end

    req.set_form files, 'multipart/form-data'
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
      return Compiler::Cpp
    when 'python'
      return Compiler::Python
    when 'ruby'
      return Compiler::Ruby
    when 'java'
      return Compiler::Java
    when 'digital'
      return Compiler::Digital
    else
      raise GraderError.new("Unsupported language (#{sub.language.name})",
                            submission_id: sub.id)
    end
  end

end