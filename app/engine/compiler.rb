require 'pathname'
require 'net/http'

class Compiler
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  SourceFilename = 'source.cpp'


  # main compile function
  def compile(box_id,sub)
    @sub = sub
    #init isolate
    setup_isolate(box_id)

    #prepare source file
    prepare_submission_directory
    prepare_files_for_compile

    #prepare params for running sandbox
    cmd = ["#{Rails.configuration.worker[:compiler][:cpp]}"]
    args = %w(-O2 -s -std=c++17 -static -DCONTEST -lm -Wall)
    args << "-o /bin/#{@sub.problem.exec_filename(@sub.language)}"
    args << "/source/#{SourceFilename}" # the source code
    cmd += args
    cmd_string = cmd.join ' '

    #run the compile in the isolated environment
    isolate_args = %w(-p -E PATH)
    output = {"/bin":@bin_path.cleanpath}
    input = {"/source":@source_path.cleanpath}
    out,err,status = run_isolate(cmd_string,input: input, output: output, isolate_args: isolate_args)

    #debug
    puts "STATUS: #{status}"
    puts "STDOUT:\n"+out
    puts "STDERR:\n"+err

    # the result should be at @bin_path
    upload_compiled_files

    #clean up isolate
    cleanup_isolate
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
    Dir.glob(@bin_path + '*').each do |fn|
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
