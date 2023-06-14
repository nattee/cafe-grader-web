require 'pathname'

class Compiler
  include IsolateRunner

  SourceFilename = 'source.cpp'


  def prepare_files(sub)
    pn = Pathname.new(Rails.configuration.worker[:directory][:judge_path]) + Grader::JudgeResultPath + sub.id.to_s
    @bin_path = pn + 'bin'
    @source_path = pn + 'source'
    @lib_path = pn + 'lib'

    #prepare folder
    @bin_path.mkpath
    @bin_path.chmod(0777)
    @source_path.mkpath
    @lib_path.mkpath

    #copy required file
    File.write(@source_path + SourceFilename,sub.source)

  end

  def compile(box_id,sub)
    #init isolate
    setup_isolate(box_id)

    #prepare params for running sandbox
    cmd = ["#{Rails.configuration.worker[:compiler][:cpp]}"]
    args = %w(-O2 -s -std=c++17 -static -DCONTEST -lm -Wall)
    args << "-o /output/#{sub.problem.exec_filename(sub.language)}"
    args << "/source/#{SourceFilename}" # the source code
    cmd += args
    cmd_string = cmd.join ' '

    #prepare source file
    prepare_files(sub)

    #run the compile in the isolated environment
    isolate_args = %w(-p -E PATH)
    input = {"/source":@source_path.cleanpath}
    output = {"/output":@bin_path.cleanpath}
    out,err,status = run_isolate(cmd_string,input: input, output: output, isolate_args: isolate_args)

    #debug
    puts "STATUS: #{status}"
    puts "STDOUT:\n"+out
    puts "STDERR:\n"+err

    # the result should be at @bin_path


    #clean up isolate
    cleanup_isolate


  end

  def self.get_compiler(sub)
    #yeah, do nothing here
    return self
  end
end
