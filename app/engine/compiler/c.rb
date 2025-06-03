class Compiler::C < Compiler
  def build_compile_command(source,bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:c]}",
      "-o #{bin}",
      "-iquote #{@isolate_source_path}",
      "-iquote #{@isolate_source_manager_path}",
      "-DEVAL -std=gnu17 -O2 -pipe -s -static",
      source
    ]
    return cmd.join ' '
  end

end
