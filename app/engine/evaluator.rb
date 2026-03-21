require 'net/http'
require 'fileutils'
require 'open3'

# This class runs the submission against a given testcases
# It also runs the checker on the output produced by the submission
# There are two mains method *execute* which runs the sub and *evaluate*
# which compare the output

class Evaluator
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  # main run function
  # run the submission against the testcase
  def execute(sub, testcase)
    @sub = sub
    @testcase = testcase
    @working_dataset = @testcase.dataset

    # init isolate
    need_cg = isolate_need_cg_by_lang(@sub.language.name)
    setup_isolate(@box_id, need_cg)

    # prepare data files
    prepare_submission_directory(@sub)
    prepare_dataset_directory(@working_dataset)
    prepare_worker_dataset(@working_dataset, :all)
    prepare_testcase_directory(@sub, @testcase)
    prepare_executable
    prepare_cocotb_data_workspace if cocotb_evaluation?

    # prepare params for running sandbox
    executable = @isolate_bin_path + @sub.problem.exec_filename(@sub.language)
    cmd = [executable, testcase.id]
    cmd_string = cmd.join ' '

    # run the evaluation in the isolated environment
    isolate_args = %w[-E PATH]
    isolate_args << isolate_options_by_lang(@sub.language.name)
    append_cocotb_isolate_env!(isolate_args)
    isolate_args += ["-o", "#{@isolate_stdout_file}"] # redirect program stdout to @isolate_stdout_file
    isolate_args += ['--stderr-to-stdout'] if input_redirect_by_lang(@sub.language.name)  # also redirect stderr, if needed
    isolate_args += ["-i", "#{@isolate_input_file}"] if input_redirect_by_lang(@sub.language.name) # redirect input, if needed
    isolate_args += ['-f 50000'] # allow max 50MB output
    # Isolate mounts "input" read-only; cocotb run.sh copies RTL to /data/student.v — use a per-run copy of dataset data (rw).
    input = {"#{@isolate_input_path}": @input_file.dirname,
             "#{@isolate_bin_path}": @mybin_path.cleanpath}
    input["#{@isolate_data_path}"] = @prob_data_path.cleanpath unless cocotb_evaluation?
    append_cocotb_sys_prefix_to_input!(input)
    input_rw = {}
    input_rw["#{@isolate_data_path}"] = @cocotb_data_workspace.cleanpath if cocotb_evaluation?
    output = {"#{@isolate_output_path}": @output_path}
    meta_file = @sub_testcase_path + 'meta.txt'

    out, err, status, meta = run_isolate(cmd_string, input: input, input_rw: input_rw, output: output, isolate_args: isolate_args, meta: meta_file,
                                  time_limit: @working_dataset.time_limit, mem_limit: @working_dataset.memory_limit,
                                  cg: need_cg)

    # also run isolate to chmod the outputfile
    run_isolate('/usr/bin/chmod 0666 '+@isolate_stdout_file.to_s, output: output, meta: nil, cg: need_cg)

    # clean up isolate
    cleanup_isolate(need_cg)

    # there should be nothing in "out" because we redirect it by -o
    # save isolate's stderr to disk
    stderr_file = @sub_testcase_path + StdErrFilename
    File.write(stderr_file, err)

    # call evaluate to check the result
    result = evaluate(out, meta, err)
    return result
  end

  # this should be called after execute, it will runs the comparator
  def evaluate(out, meta, err)
    judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} checking execution result..."
    e = Evaluation.find_or_create_by(submission: @sub, testcase: @testcase)

    # any error?
    unless meta['status'].blank?
      judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} forced exit by isolate (#{Rainbow(meta['status']).color(COLOR_EVALUATION_FORCE_EXIT)}) #{Rainbow(err).color(COLOR_EVALUATION_FORCE_EXIT)} "
      time = meta['time'] || meta['time-wall'] || 0
      if meta['status'] == 'SG'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :crash)
      elsif meta['status'] == 'TO'
        e.update(time: meta['time-wall'] * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :time_limit)
      elsif meta['status'] == 'RE'
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :crash)
      elsif meta['status'] == 'XX'
        e.update(isolate_message: meta['message'], result: :grader_error)
      else
        # other status
        e.update(time: time * 1000, memory: meta['max-rss'], isolate_message: meta['message'], result: :unknown_error)
      end
    else
      judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} ends normally"
      # ends normally, runs the comparator
      checker = Checker.get_checker(@sub).new(@worker_id, @box_id)
      check_result = checker.process(@sub, @testcase)
      e.update(time: meta['time'] * 1000, memory: meta['max-rss'],
                result: check_result[:result], score: check_result[:score],
                result_text: (check_result[:comment] || '').truncate(250))
    end

    # save final result
    judge_log "#{rb_sub(@sub)} Testcase: #{rb_testcase(@testcase)} Evaluation #{Rainbow('done').color(COLOR_EVALUATION_DONE)}"
    return EngineResponse::Result.success(result_description: "Evaluation completed successfully")
  end

  def cocotb_evaluation?
    @working_dataset.evaluation_type.to_s == 'cocotb'
  end

  # Runtime env wins over worker.yml (so systemd Environment=COCOTB_PYTHON=... works without editing YAML).
  def resolved_cocotb_python_path
    raw = ENV['COCOTB_PYTHON'].presence || Rails.configuration.worker.dig(:compiler, :cocotb_python).to_s.strip
    return if raw.blank?
    File.expand_path(raw)
  end

  # Put the configured Python (with cocotb) first on PATH inside isolate so grade.sh's `python3` finds site-packages.
  def append_cocotb_isolate_env!(isolate_args)
    return unless cocotb_evaluation?
    py = resolved_cocotb_python_path
    unless py && File.executable?(py)
      judge_log "cocotb: cocotb_python not executable (#{py.inspect}); set COCOTB_PYTHON or compiler.cocotb_python in worker.yml to your venv's python3 (pip install cocotb there)", Logger::WARN
      return
    end
    bin_dir = File.dirname(py)
    # isolate: -E VAR=val sets env (-e is --full-env, not variable assignment)
    isolate_args << '-E' << "PATH=#{bin_dir}:#{ENV['PATH']}"
  end

  # Isolate does not expose arbitrary host paths; bind-mount Python's sys.prefix read-only (like Python lang's -d /venv).
  def append_cocotb_sys_prefix_to_input!(input)
    return unless cocotb_evaluation?
    py = resolved_cocotb_python_path
    return unless py && File.executable?(py)
    prefix = cocotb_sys_prefix(py)
    return unless mountable_cocotb_prefix?(prefix)
    input[prefix] = Pathname(prefix).cleanpath
  end

  def cocotb_sys_prefix(py_bin)
    out, status = Open3.capture2(py_bin, '-c', 'import sys; print(sys.prefix)')
    return unless status.success?
    out.to_s.strip.presence
  end

  def mountable_cocotb_prefix?(prefix)
    return false if prefix.blank?
    p = Pathname.new(prefix).cleanpath.to_s
    return false if p == '/' || p == '/usr'
    return false if p.start_with?('/usr/')
    File.directory?(p)
  end

  # Writable snapshot of dataset data/ for cocotb (run.sh writes student.v; shared prob data/ stays read-only on disk).
  def prepare_cocotb_data_workspace
    @cocotb_data_workspace = @sub_testcase_path + 'cocotb_data'
    FileUtils.rm_rf(@cocotb_data_workspace) if @cocotb_data_workspace.exist?
    if @prob_data_path.exist? && @prob_data_path.directory?
      FileUtils.cp_r(@prob_data_path, @cocotb_data_workspace)
    else
      @cocotb_data_workspace.mkpath
    end
    # Isolate runs the submission as a sandbox uid (often not the grader); dataset files are 644/755 → Permission denied on cp to /data/student.v
    FileUtils.chmod_R(0777, @cocotb_data_workspace.to_s)
  end

  def prepare_executable
    @mybin_path = @bin_path + @box_id.to_s
    @mybin_path.mkpath

    # download each compiled files
    @sub.compiled_files.each do |attachment|
      filename = @mybin_path + attachment.filename.to_s

      # download from server
      url = Rails.configuration.worker[:hosts][:web]+worker_get_compiled_submission_path(@sub, attachment.id)
      begin
        download_from_web(url, filename, download_type: 'executable', chmod_mode: 'a+x')
      rescue Net::HTTPExceptions => he
        raise GraderError.new("Error download compiled file \"#{he}\"", submission_id: @sub.id)
      end
      FileUtils.chmod('a+x', filename)
    end
  end


  # return appropriate evaluator class for the submission
  def self.get_evaluator(submission)
    # TODO: should return appropriate compiler class
    return self
  end
end
