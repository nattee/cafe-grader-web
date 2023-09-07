class Compiler::Digital < Compiler
  def build_compile_command(source,bin)
    # this basically is no-op
    cmd = [
      "echo "
    ]
    return cmd.join ' '
  end

  def post_compile(source,bin)
    bin_text = "#!/bin/sh\njava -cp #{Rails.configuration.worker[:compiler][:ruby]} " +
      "CLI TEST " +
      "-circ #{source} " +
      "-test /input/input.txt \n"
    File.write(bin,bin_text)
  end
end
