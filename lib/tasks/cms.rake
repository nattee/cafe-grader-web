# CMS -> cafe task clone. Spec: docs/superpowers/specs/2026-08-02-cms-clone-import-design.md
# Connection settings: config/cms_remote.yml (NOT committed; see the .sample)
# or ENV CMS_SSH_HOST / CMS_REMOTE_PYTHON.
namespace :cms do
  desc 'Clone a task from the remote CMS. Usage: rails "cms:clone[task_name]"'
  task :clone, %i[name] => :environment do |_t, args|
    require 'open3'
    require 'tmpdir'

    name = args[:name].to_s
    abort 'Usage: rails "cms:clone[<task_name>]"' if name.blank?
    # Task name goes onto the remote command line -- keep it shell-inert.
    abort "Task name '#{name}' contains unsupported characters" unless name.match?(/\A[\w.\-]+\z/)

    cfg_file = Rails.root.join('config', 'cms_remote.yml')
    cfg = File.exist?(cfg_file) ? YAML.safe_load(File.read(cfg_file), symbolize_names: true) : {}
    host   = ENV['CMS_SSH_HOST'] || cfg[:host]
    python = ENV['CMS_REMOTE_PYTHON'] || cfg[:python] || '/home/cms/cms_venv/bin/python3'
    abort 'Set CMS_SSH_HOST or create config/cms_remote.yml (see config/cms_remote.yml.sample)' if host.blank?

    if (existing = Problem.find_by(name: name))
      puts "NOTE: problem '#{name}' already exists (id #{existing.id}); " \
           'the import will ADD a new dataset generation to it (live dataset unchanged).'
    end

    script = Rails.root.join('script', 'cms_extract', 'extract_task.py')
    Dir.mktmpdir('cms_clone_') do |tmp|
      tar_path = File.join(tmp, 'bundle.tar')
      puts "Extracting '#{name}' from #{host} ..."
      cmd = ['ssh', '-o', 'BatchMode=yes', host,
             'sudo', '-n', '-u', 'cms', python, '-', name]
      status = nil
      File.open(tar_path, 'wb') do |out|
        Open3.popen3(*cmd) do |stdin, stdout, stderr, wait|
          stdin.write(File.read(script))
          stdin.close
          err_thread = Thread.new { stderr.each_line { |l| warn "  [cms] #{l.chomp}" } }
          IO.copy_stream(stdout, out)
          err_thread.join
          status = wait.value
        end
      end
      abort 'Extraction failed (see [cms] lines above).' unless status&.success?

      system('tar', '-xf', tar_path, '-C', tmp) or abort 'could not untar bundle'
      bundle_dir = File.join(tmp, 'bundle')
      staging = File.join(tmp, 'staging')

      conv = Converters::CmsDumpConverter.new
      res = conv.convert(bundle_dir, staging)
      res[:log].each      { |l| puts "  #{l}" }
      res[:warnings].each { |w| puts "  WARNING: #{w}" }
      if res[:errors].any?
        res[:errors].each { |e| warn "  ERROR: #{e}" }
        abort 'Conversion rejected the task; nothing was imported.'
      end

      meta = conv.problem_meta
      pi = ProblemImporter.new
      log = pi.import_dataset_from_dir(staging, meta[:name], full_name: meta[:full_name])
      puts(log.is_a?(Array) ? log.map { |l| "  #{l}" }.join("\n") : "  #{log}")
      abort "Import errors: #{pi.errors.join('; ')}" if pi.errors.any?

      # Carry the CMS dataset name onto the live dataset (importer auto-names it).
      pi.dataset.update(name: meta[:live_dataset_name]) if meta[:live_dataset_name].present?
      puts "Cloned '#{meta[:name]}' -> problem id #{pi.problem.id} " \
           "(#{pi.problem.datasets.count} dataset(s); available=false until you enable it)."
    end
  end
end
