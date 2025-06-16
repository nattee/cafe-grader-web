class Compiler::Verilog < Compiler
  SUBMIT_VERILOG_FILENAME = 'submitted.v'

  def build_compile_command(source,bin)
    # run just for checking syntax error
    cmd = [
      "#{Rails.configuration.worker[:compiler][:iverilog]}",
      source
    ]
    return cmd.join ' '
  end

  # build a script that build and run each verilog file
  def post_compile
    # running script
    bin_text = "#!/bin/sh\n#{Rails.configuration.worker[:compiler][:iverilog]} -o run #{@isolate_bin_path}/#{SUBMIT_VERILOG_FILENAME}  #{@isolate_input_file}\n#{Rails.configuration.worker[:compiler][:vvp]} run"
    File.write(@exec_file,bin_text)

    FileUtils.cp(@source_file, @compile_path + SUBMIT_VERILOG_FILENAME)
  end
end
