class Compiler::Verilog < Compiler
  SUBMIT_VERILOG_FILENAME = 'submitted.v'

  def build_compile_command(source, bin)
    # cocotb: harness (grade.sh / simulator) does the real check; iverilog may be absent on the worker.
    # Without a valid iverilog path, isolate would try to exec /source/submission.v → execve permission denied (127).
    return '/bin/true' if cocotb_run?

    iv = Rails.configuration.worker[:compiler][:iverilog].to_s.strip
    if iv.blank?
      raise GraderError.new(
        'worker.yml is missing compiler.iverilog (install iverilog or set compiler.iverilog path)',
        submission_id: @sub.id
      )
    end

    # Non–cocotb: quick syntax check with iverilog
    [iv, source.to_s].join(' ')
  end

  # build a script that build and run each verilog file
  def post_compile
    FileUtils.cp(@source_file, @compile_path + SUBMIT_VERILOG_FILENAME)

    if cocotb_run?
      # Paths are isolate paths (/mybin, /data). grade.sh must exit 0 on pass, non-zero on fail.
      # Send test harness output to stderr so stdout is only OK/WRONG.
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
    else
      bin_text = "#!/bin/sh\n#{Rails.configuration.worker[:compiler][:iverilog]} -o run #{@isolate_bin_path}/#{SUBMIT_VERILOG_FILENAME}  #{@isolate_input_file}\n#{Rails.configuration.worker[:compiler][:vvp]} run"
    end
    File.write(@exec_file, bin_text)
  end

  def cocotb_run?
    @working_dataset.evaluation_type == 'cocotb'
  end
end