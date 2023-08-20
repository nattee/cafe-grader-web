class Compiler::Ruby < Compiler
  def build_compile_command(source,bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:ruby]}",
      "-c \"#{source}\"",
    ]
    return cmd.join ' '
  end

  def post_compile(source,bin)
    source_text = File.read(source)

    bin_text = "#!#{Rails.configuration.worker[:compiler][:ruby]}\n"+source_text
    File.write(bin,bin_text)
  end
end
