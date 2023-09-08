class Compiler::Digital < Compiler
  SUBMIT_DIGITAL_FILENAME = 'submitted.dig'
  def build_compile_command(source,bin)
    # this basically is no-op
    cmd = [
      "/usr/bin/echo "
    ]
    return cmd.join ' '
  end

  def post_compile
    # running script
    bin_text = "#!/bin/sh\njava -cp #{Rails.configuration.worker[:compiler][:ruby]} " +
      "CLI TEST " +
      "-circ #{@isolate_bin_path}/#{SUBMIT_DIGITAL_FILENAME} " +
      "-test #{@isolate_input_file}\n"
    File.write(@exec_file,bin_text)

    # the submitted file
    FileUtils.cp(@source_file,SUBMIT_DIGITAL_FILENAME)
  end
end
