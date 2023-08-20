class Compiler::Java < Compiler
  def pre_compile(source,bin)
    @classname = nil
    @new_source_file = @compile_path + "#{@classname}.java"
    new_source = []

    @sub.source.each_line do |line|
      line.encode!('UTF-8','UTF-8',invalid: :replace, replace: '')
      md = /\s*public\s*class\s*(\w*)/.match(line)
      @classname=md[1] if md
      new_source += line unless line =~ /\s*package\s*\w+\s*\;/
    end

    if @classname
      File.write(@new_source_file,new_source.join("\n"))
    end
  end

  def build_compile_command(source,bin)
    cmd = [
      "#{Rails.configuration.worker[:compiler][:javac]}",
      "-encoding utf8",
      @isolate_source_path + "#{@classname}.java",
      "-d #{@isolate_bin_path}",
    ]
    return cmd.join ' '
  end

  def post_compile(source,bin)
    source_text = File.read(source)

    bin_text = "#!#{Rails.configuration.worker[:compiler][:ruby]}\n"+source_text
    File.write(bin,bin_text)
  end
end
