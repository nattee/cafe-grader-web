class Compiler::Cpp < Compiler
  def build_compile_command(source,bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:cpp]}",
      "-o #{bin}",
      "-iquote #{@isolate_source_path}",
      "-iquote #{@isolate_source_manager_path}",
      "-DEVAL -std=gnu++17 -O2 -pipe -s -static",
      source
    ]
    return cmd.join ' '
  end

end
