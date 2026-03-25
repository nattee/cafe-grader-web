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

  # Creates run.sh: copy submitted.v to /data/student.v, run /data/grade.sh.
  # Harness must print PASS/FAIL lines to stdout. Verilog stdin is the testcase input.txt (first line = subtest key for multi-testcase cocotb; see Checker).
  def post_compile
    FileUtils.cp(@source_file, @compile_path + SUBMIT_VERILOG_FILENAME)

    bin_text = <<~SH
      #!/bin/sh
      export STUDENT_V=/mybin/#{SUBMIT_VERILOG_FILENAME}
      if [ ! -f "/mybin/#{SUBMIT_VERILOG_FILENAME}" ]; then
        echo "grader: missing compiled RTL /mybin/#{SUBMIT_VERILOG_FILENAME}" >&2
        echo "FAIL grader_missing_rtl"
        exit 0
      fi
      if ! cp -f "/mybin/#{SUBMIT_VERILOG_FILENAME}" /data/student.v; then
        echo "grader: failed to copy RTL to /data/student.v" >&2
        echo "FAIL grader_copy_rtl"
        exit 0
      fi
      cd /data
      if [ ! -f /data/grade.sh ]; then
        echo "grader: cocotb problem requires /data/grade.sh" >&2
        echo "FAIL grader_missing_grade_sh"
        exit 0
      fi
      sh /data/grade.sh
      exit 0
    SH
    File.write(@exec_file, bin_text)
  end
end
