class Compiler::Python < Compiler
  def build_compile_command(source,bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:python]}",
      "-c \"import py_compile; py_compile.compile('#{source}','#{bin}')\"",
    ]
    return cmd.join ' '
  end
end
