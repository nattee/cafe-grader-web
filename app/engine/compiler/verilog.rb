class Compiler::Verilog < Compiler
  SUBMIT_VERILOG_FILENAME = 'submitted.v'

  def validate
    super
    unless @working_dataset.cocotb?
      raise GraderError.new(
        'Verilog submissions require dataset evaluation_type cocotb (legacy iverilog+vvp is no longer supported)',
        submission_id: @sub.id
      )
    end
  end

  # grade.sh does the real check; compile step only uploads submitted.v + run.sh.
  def build_compile_command(_source, _bin)
    '/bin/true'
  end

  # Creates run.sh: copy submitted.v to /data/student.v, run /data/grade.sh, print OK/WRONG.
  def post_compile
    FileUtils.cp(@source_file, @compile_path + SUBMIT_VERILOG_FILENAME)

    # paths are isolate paths (/mybin, /data). grade.sh must exit 0 on pass, non-zero on fail.
    # grade.sh must output to stderr so stdout is only OK/WRONG.
    bin_text = <<~SH
      #!/bin/sh
      export STUDENT_V=/mybin/#{SUBMIT_VERILOG_FILENAME}
      if [ ! -f "/mybin/#{SUBMIT_VERILOG_FILENAME}" ]; then
        echo "grader: missing compiled RTL /mybin/#{SUBMIT_VERILOG_FILENAME}" >&2
        echo WRONG
        exit 0
      fi
      if ! cp -f "/mybin/#{SUBMIT_VERILOG_FILENAME}" /data/student.v; then
        echo "grader: failed to copy RTL to /data/student.v" >&2
        echo WRONG
        exit 0
      fi
      cd /data
      if [ ! -f /data/grade.sh ]; then
        echo WRONG
        echo "grader: cocotb problem requires /data/grade.sh (see doc/cocotb_problem.md)" >&2
        exit 0
      fi
      sh /data/grade.sh
      RC=$?
      if [ "$RC" -eq 0 ]; then
        echo OK
      else
        echo WRONG
      fi
      exit 0
    SH
    File.write(@exec_file, bin_text)
  end
end
