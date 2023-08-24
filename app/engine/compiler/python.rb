class Compiler::Python < Compiler
  def build_compile_command(isolate_source,isolate_bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:python]}",
      "-c \"import py_compile; py_compile.compile('#{isolate_source}','#{isolate_bin}')\"",
    ]
    return cmd.join ' '
  end

  def check_compile_result(out,err,status,meta)
    if File.exist?(@exec_file)
      #compiler finished successfully
      return {success: true, compiler_message: out}
    else
      #compiler found some error
      return {success: false, compiler_message: err}
    end
  end

end
