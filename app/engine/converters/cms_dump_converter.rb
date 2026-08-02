require 'json'
require 'open3'
require 'fileutils'

# Converts a CMS task bundle — produced by script/cms_extract/extract_task.py:
# the official cmsDumpExporter subtree (task.json) plus digest-addressed blobs
# (files/<sha1>) — into the canonical cafe staging directory consumed by
# ProblemImporter. Pure dir→dir; never touches the database.
#
# Multi-dataset: the CMS active dataset becomes the root (live) layout; every
# other importable dataset becomes datasets/<name>/ per the additive zip
# format (doc/multi-dataset-export-import-design-2026-07-16.md).
#
# Reject/skip matrix (spec §Rejection): non-Batch task type, file-I/O, and
# unsupported score types reject the TASK when found on the active dataset,
# and skip just that DATASET (warning) when found on a non-active one.
#
# On errors the staging dir may be partially written — callers must not
# import unless the returned :errors is empty.
# Spec: docs/superpowers/specs/2026-08-02-cms-clone-import-design.md
class Converters::CmsDumpConverter
  SUPPORTED_BUNDLE_VERSION = 1
  # cms.db version on c2 (CMS 1.4.dev3). On drift: re-verify the field mapping
  # against the new dump schema, then bump.
  SUPPORTED_DUMP_VERSION = 39

  SCORE_TYPE_MAP = { 'Sum' => 'sum', 'GroupMin' => 'group_min' }.freeze
  EVAL_MAP       = { 'diff' => 'default', 'comparator' => 'custom_cms' }.freeze

  # Attachment filenames that would collide with ProblemImporter's root-level
  # recursive globs (*.pdf statement, *.md description, *.in/*.sol testcases)
  # get wrapped in a zip instead of shipped bare.
  RISKY_ATTACHMENT = /\.(pdf|md|in|sol|yml)\z/i

  attr_reader :log, :warnings, :errors, :problem_meta

  def initialize
    @log = []
    @warnings = []
    @errors = []
    @problem_meta = {}
  end

  # bundle_dir: dir holding task.json + files/<digest>
  # staging_dir: output dir (created here)
  # => {log:, warnings:, errors:}
  def convert(bundle_dir, staging_dir)
    @bundle  = Pathname.new(bundle_dir)
    @staging = Pathname.new(staging_dir)
    catch(:reject) do
      parse_bundle
      plan_datasets
      write_staging
    end
    { log: @log, warnings: @warnings, errors: @errors }
  end

  private

  def reject!(msg)
    @errors << msg
    throw :reject
  end

  def parse_bundle
    tj = @bundle + 'task.json'
    reject!("bundle has no task.json (#{tj})") unless tj.exist?
    @data = JSON.parse(File.read(tj))
    unless @data['bundle_version'] == SUPPORTED_BUNDLE_VERSION
      reject!("unsupported bundle_version #{@data['bundle_version'].inspect} " \
              "(supported: #{SUPPORTED_BUNDLE_VERSION})")
    end
    unless @data['dump_version'] == SUPPORTED_DUMP_VERSION
      reject!("unsupported CMS dump _version #{@data['dump_version'].inspect} " \
              "(supported: #{SUPPORTED_DUMP_VERSION}; re-verify the mapping " \
              'against the new dump schema before bumping SUPPORTED_DUMP_VERSION)')
    end
    @objects = @data['objects']
    reject!('bundle has no objects map') unless @objects.is_a?(Hash)
    @task = @objects[@data['task_id'].to_s]
    reject!('task_id missing from objects') unless @task && @task['_class'] == 'Task'
    @log << "task '#{@task['name']}' (#{@task['title']}), #{(@task['datasets'] || []).size} dataset(s)"
    @log << 'instance-local CMS fields skipped: token_*, max_submission_number, ' \
            'max_user_test_number, score_mode, score_precision, per-testcase public flags'
  end

  def plan_datasets
    active_id = @task['active_dataset'].to_s
    @active = @objects[active_id]
    reject!('task has no active dataset') unless @active
    reasons = dataset_reject_reasons(@active)
    if reasons.any?
      reject!("active dataset '#{ds_display_name(@active)}': #{reasons.join('; ')}")
    end
    @others = []
    (@task['datasets'] || []).map(&:to_s).reject { |i| i == active_id }.each do |id|
      ds = @objects[id]
      rs = dataset_reject_reasons(ds)
      if rs.any?
        @warnings << "skipped non-active dataset '#{ds_display_name(ds)}': #{rs.join('; ')}"
      else
        @others << ds
      end
    end
    @problem_meta = { name: @task['name'], full_name: @task['title'],
                      live_dataset_name: ds_display_name(@active) }
  end

  # Unsupported CMS features per the standing non-goals (doc/backlog.md):
  # Communication/OutputOnly/TwoSteps task types, file-I/O batch tasks,
  # GroupMinPrereq (and any other unknown) scoring.
  def dataset_reject_reasons(ds)
    unless ds['task_type'] == 'Batch'
      return ["task_type '#{ds['task_type']}' not supported (only Batch; see doc/backlog.md)"]
    end

    reasons = []
    compilation, io, eval_mode = ds['task_type_parameters']
    if io.is_a?(Array) && io.any? { |f| f.to_s != '' }
      reasons << "file-I/O task (infile/outfile #{io.inspect}) not supported (see doc/backlog.md)"
    end
    reasons << "unknown Batch compilation #{compilation.inspect}" unless %w[grader alone].include?(compilation)
    unless SCORE_TYPE_MAP.key?(ds['score_type'])
      reasons << "score_type '#{ds['score_type']}' not supported (GroupMinPrereq: see doc/backlog.md)"
    end
    reasons << "unknown Batch output evaluation #{eval_mode.inspect}" unless EVAL_MAP.key?(eval_mode)
    if eval_mode == 'comparator' && !(ds['managers'] || {}).key?('checker')
      reasons << "comparator evaluation but no 'checker' manager"
    end
    if compilation == 'grader' && (ds['managers'] || {}).keys.none? { |n| n != 'checker' && n.end_with?('.cpp') }
      reasons << 'grader compilation but no .cpp manager to use as main file'
    end
    if SCORE_TYPE_MAP.key?(ds['score_type'])
      _plan, plan_errors = build_group_plan(ds)
      reasons.concat(plan_errors)
    end
    reasons
  end

  # => [ {codename => {group:, group_name:, weight:}}, [error strings] ]
  # Deterministic; called once for validation and once for writing.
  def build_group_plan(ds)
    codenames = (ds['testcases'] || {}).keys
    bad = codenames.reject { |c| c.match?(/\A[\w.\-]+\z/) }
    return [{}, ["unsafe testcase codenames: #{bad.join(', ')}"]] if bad.any?

    # CMS ScoreTypeGroup consumes testcases in lexicographic codename order.
    sorted = codenames.sort
    case ds['score_type']
    when 'Sum'
      [sorted.to_h { |c| [c, { group: 1, group_name: '1', weight: 1 }] }, []]
    when 'GroupMin'
      params = ds['score_type_parameters']
      unless params.is_a?(Array) && params.all? { |p| p.is_a?(Array) && p.size == 2 }
        return [{}, ["GroupMin parameters malformed: #{params.inspect}"]]
      end
      if params.all? { |_m, t| t.is_a?(Integer) }
        total = params.sum { |_m, t| t }
        unless total == sorted.size
          return [{}, ["GroupMin testcase counts sum to #{total} but dataset has #{sorted.size} testcases"]]
        end
        plan = {}
        cursor = 0
        params.each_with_index do |(points, count), i|
          sorted[cursor, count].each do |c|
            plan[c] = { group: i + 1, group_name: (i + 1).to_s, weight: points }
          end
          cursor += count
        end
        [plan, []]
      elsif params.all? { |_m, t| t.is_a?(String) }
        plan = {}
        errs = []
        params.each_with_index do |(points, pattern), i|
          re = /\A(?:#{pattern})/ # CMS uses re.match => start-anchored
          sorted.each do |c|
            next unless re.match?(c)
            if plan.key?(c)
              errs << "testcase '#{c}' matches multiple GroupMin patterns " \
                      "(groups #{plan[c][:group]} and #{i + 1})"
            else
              plan[c] = { group: i + 1, group_name: (i + 1).to_s, weight: points }
            end
          end
        end
        uncovered = sorted - plan.keys
        errs << "testcases match no GroupMin pattern: #{uncovered.join(', ')}" if uncovered.any?
        [errs.any? ? {} : plan, errs]
      else
        [{}, ['GroupMin parameters mix integer and regex styles (unsupported)']]
      end
    else
      [{}, []] # unreachable: score_type gated in dataset_reject_reasons
    end
  end

  def write_staging
    @staging.mkpath
    cfg = problem_level_config
    write_dataset_into(@active, @staging, cfg)
    write_statement
    write_attachments
    additional = []
    @others.each do |ds|
      dirname = unique_dirname(additional, ds_display_name(ds))
      dir = @staging + ProblemImporter::RESERVED_DATASETS_DIRNAME + dirname
      frag = { ds_name: ds_display_name(ds) }
      write_dataset_into(ds, dir, frag)
      write_yaml(dir + OptionConst::YAML_FILENAME, frag)
      additional << dirname
      @log << "additional dataset '#{ds_display_name(ds)}' -> " \
              "#{ProblemImporter::RESERVED_DATASETS_DIRNAME}/#{dirname}/"
    end
    cfg[:additional_datasets] = additional if additional.any?
    write_yaml(@staging + OptionConst::YAML_FILENAME, cfg)
    @log << 'staging dir ready'
  end

  def problem_level_config
    compilation, _io, _eval_mode = @active['task_type_parameters']
    fmt = @task['submission_format'] || []
    if fmt.size != 1
      @warnings << "submission_format has #{fmt.size} entries (#{fmt.inspect}); using the first"
    end
    submission_filename = (fmt.first || "#{@task['name']}.%l").gsub('%l', 'cpp')
    cfg = {
      name: @task['name'],
      full_name: @task['title'],
      task_type: 'batch',
      compilation_type: compilation == 'grader' ? 'with_managers' : 'self_contained',
      submission_filename: submission_filename,
      ds_name: ds_display_name(@active)
    }
    # Grader-linked tasks compile as C++ on the cafe judge (compiler/cpp.rb
    # globs manager + submission .cpp files together).
    cfg[:permitted_lang] = 'cpp' if compilation == 'grader'
    cfg
  end

  # Writes ds's files under dir and fills cfg with the dataset-scoped fields
  # (OptionConst::DATASET_OPTION_FIELDS subset) + the testcases hash.
  def write_dataset_into(ds, dir, cfg)
    dir.mkpath
    compilation, _io, eval_mode = ds['task_type_parameters']
    cfg[:time_limit]      = ds['time_limit'].to_f
    cfg[:memory_limit]    = ds['memory_limit'].to_i
    cfg[:score_type]      = SCORE_TYPE_MAP.fetch(ds['score_type'])
    cfg[:evaluation_type] = EVAL_MAP.fetch(eval_mode)

    managers = ds['managers'] || {}
    if (checker_id = managers['checker'])
      copy_blob(@objects[checker_id]['digest'], dir + 'checker' + 'checker')
      @warnings << "dataset '#{ds_display_name(ds)}': CMS comparator copied as checker/checker — " \
                   'CMS checkers are prebuilt binaries; verify it runs on the cafe judge host ' \
                   '(or replace with recompiled source)'
    end
    manager_names = managers.keys - ['checker']
    manager_names.each do |name|
      copy_blob(@objects[managers[name]]['digest'], dir + 'managers' + name)
    end
    if compilation == 'grader'
      main = manager_names.include?('grader.cpp') ? 'grader.cpp' : manager_names.sort.find { |n| n.end_with?('.cpp') }
      cfg[:main] = [main]
      cfg[:main_filename] = main
    end

    plan, _errs = build_group_plan(ds)
    if ds['score_type'] == 'Sum'
      @log << "dataset '#{ds_display_name(ds)}': CMS Sum " \
              "(params #{ds['score_type_parameters'].inspect}) -> cafe sum, every testcase weight 1"
    end
    tc_cfg = {}
    (ds['testcases'] || {}).sort.each do |codename, tc_id|
      tc = @objects[tc_id.to_s]
      copy_blob(tc['input'],  dir + 'testcases' + "#{codename}.in")
      copy_blob(tc['output'], dir + 'testcases' + "#{codename}.sol")
      tc_cfg[codename] = plan[codename]
    end
    cfg[:testcases] = tc_cfg
    @log << "dataset '#{ds_display_name(ds)}': #{tc_cfg.size} testcases, " \
            "#{plan.values.map { |v| v[:group] }.uniq.size} group(s)"
  end

  def write_statement
    statements = @task['statements'] || {}
    if statements.empty?
      @warnings << 'task has no statement PDF'
      return
    end
    primary = (@task['primary_statements'] || []).first
    lang = [primary, 'th', 'en'].compact.find { |l| statements.key?(l) } || statements.keys.sort.first
    copy_blob(@objects[statements[lang]]['digest'], @staging + OptionConst::DEFAULT[:file][:statement])
    @log << "statement: language '#{lang}' -> #{OptionConst::DEFAULT[:file][:statement]}"
    (statements.keys - [lang]).sort.each do |l|
      @warnings << "statement language '#{l}' skipped (cafe holds one statement)"
    end
  end

  def write_attachments
    atts = (@task['attachments'] || {}).map { |name, id| [name, @objects[id.to_s]['digest']] }
    return if atts.empty?

    dir = @staging + OptionConst::DEFAULT[:dir][:attachment]
    if atts.size == 1 && atts.first.first !~ RISKY_ATTACHMENT
      name, digest = atts.first
      copy_blob(digest, dir + name)
      @log << "attachment: #{name}"
    else
      tmp = @staging + 'attachment_tmp'
      atts.each { |name, digest| copy_blob(digest, tmp + name) }
      dir.mkpath
      zip_name = "#{@task['name']}-files.zip"
      out, err, status = Open3.capture3('zip', '-j', (dir + zip_name).to_s,
                                        *atts.map { |name, _| (tmp + name).to_s })
      reject!("zip of attachments failed: #{err.presence || out}") unless status.success?
      FileUtils.rm_rf(tmp)
      @log << "attachments bundled into #{zip_name}: #{atts.map(&:first).join(', ')}"
    end
  end

  def copy_blob(digest, dest)
    src = @bundle + 'files' + digest.to_s
    reject!("bundle blob missing: #{digest}") unless src.exist?
    dest.dirname.mkpath
    FileUtils.cp(src, dest)
  end

  def ds_display_name(ds)
    ds['description'].presence || 'unnamed'
  end

  def unique_dirname(taken, display_name)
    base = display_name.parameterize
    base = 'dataset' if base.blank?
    candidate = base
    n = 1
    while taken.include?(candidate)
      n += 1
      candidate = "#{base}-#{n}"
    end
    candidate
  end

  def write_yaml(path, hash)
    path.dirname.mkpath
    File.write(path, hash.deep_stringify_keys.to_yaml)
  end
end
