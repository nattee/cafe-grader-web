class Compiler::Digital < Compiler
  SUBMIT_DIGITAL_FILENAME = 'submitted.dig'
  def build_compile_command(source, bin)
    # this basically is no-op
    cmd = [
      "/usr/bin/echo "
    ]
    return cmd.join ' '
  end

  def post_compile
    if @sub.submitted_archive?
      # multi-file circuit project: unzip beside the main circuit (Digital
      # resolves custom components by bare filename), copy THE main file to
      # the submitted name so the eval script below stays unchanged
      extract_archive(@source_file, @compile_path)
      main = archive_main_file(@compile_path, ext: 'dig')
      FileUtils.cp(@compile_path + main, @compile_path + SUBMIT_DIGITAL_FILENAME)
    else
      # single-file submission
      FileUtils.cp(@source_file, @compile_path + SUBMIT_DIGITAL_FILENAME)
    end

    # running script
    bin_text = "#!/bin/sh\njava -cp /my_lib/Digital.jar " +
      "CLI test " +
      "-circ #{@isolate_bin_path}/#{SUBMIT_DIGITAL_FILENAME} " +
      "-tests #{@isolate_input_file}\n"
    File.write(@exec_file, bin_text)
  end
end
