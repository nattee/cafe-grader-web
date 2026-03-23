# Cocotb (Verilog) evaluation: writable /data snapshot, Python PATH, venv bind-mount.
# Kept separate from Evaluator so execute stays small; digital has no analogue (no rw data copy).
module EvaluatorCocotb
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
    FileUtils.chmod_R(0777, @cocotb_data_workspace.to_s)
  end

  # Mount /data read-only from prob tree, or rw copy + Python extras + PATH (cocotb only).
  def configure_evaluate_isolate_inputs!(isolate_args, input, input_rw)
    append_cocotb_isolate_env!(isolate_args)

    if cocotb_evaluation?
      prepare_cocotb_data_workspace
      append_cocotb_sys_prefix_to_input!(input)
      input_rw["#{@isolate_data_path}"] = @cocotb_data_workspace.cleanpath
    else
      input["#{@isolate_data_path}"] = @prob_data_path.cleanpath
    end
  end
end
