class Compiler::Jupyter < Compiler
  SUBMIT_SOURCE_FILENAME = 'jupyter_code.py'
  RUN_FILENAME = 'checker_added.py'

  def build_compile_command(isolate_source,isolate_bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:python]}",
      "-c \"import py_compile; py_compile.compile('#{@isolate_bin_path}/#{SUBMIT_SOURCE_FILENAME}','#{@isolate_bin_path}/#{SUBMIT_SOURCE_FILENAME}c')\"",
    ]
    return cmd.join ' '
  end

  def check_compile_result(out,err,status,meta)
    if File.exist?("#{@compile_path}/#{SUBMIT_SOURCE_FILENAME}c")
      #compiler finished successfully
      return {success: true, compiler_message: out}
    else
      #compiler found some error
      return {success: false, compiler_message: err}
    end
  end

  def pre_compile
    jupyter_nb = JSON.parse(@sub.binary)
    code = ["import sys"]
    jupyter_nb["cells"].each do |cell|
      next if cell["cell_type"] != "code"
      cell["source"].each do |line|
        line = line.rstrip
        if line.start_with?("# +!+=")
          fname = line.split("=").last
          code << "if '___cafe_jupyter__checker___#{fname}' in dir(): ___cafe_jupyter__checker___#{fname}()"
        elsif line.start_with?("%")
          code << "#  #{line}"
        else
          code << line
        end
      end
      code << ""
    end
    code << "sys.exit(\"reached the end of program without encountering checker\")\n"
    File.write("#{@compile_path}/#{SUBMIT_SOURCE_FILENAME}", code.join("\n"))
  end

  # build a script that build and run each verilog file
  def post_compile
    # running script
    bin_text = "#!/bin/sh\ncat #{@isolate_input_file} #{@isolate_bin_path}/#{SUBMIT_SOURCE_FILENAME} > #{RUN_FILENAME}\n#{Rails.configuration.worker[:compiler][:python]} #{RUN_FILENAME}\n"
    File.write(@exec_file,bin_text)
  end
end
