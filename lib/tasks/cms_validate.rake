# CMS-source submission-replay validation ("Mode B", doc/CMS-Migration.md
# Sec 3): rails "cms:validate[<task_name_or_ALL>,<per_band_limit>]".
#
# For each task: streams script/cms_extract/extract_submissions.py over ssh
# (same shape as cms:clone's extraction), grades the sampled CMS submissions
# through the real cafe judge via Replay::CmsReplay.run, and diffs against
# CMS's recorded results -- CMS's grades are the oracle. Read-only against
# CMS; every submission it creates locally is destroyed by CmsReplay.run.
#
# Deliberately a SEPARATE file from cms.rake (owned by a different,
# concurrently-edited task) to avoid a collision while both are under
# active development -- do not merge them without coordinating.
require 'open3'
require 'net/http'

module CmsValidateSupport
  module_function

  # Best-effort reader across a couple of plausible bulk-clone manifest
  # shapes. The manifest itself (tmp/cms_clone_all_*.json) is written by the
  # bulk-clone rake task in lib/tasks/cms.rake, built concurrently with this
  # file, so its exact format isn't locked down here -- this stays
  # deliberately permissive rather than coupling tightly to a shape that may
  # still change. Accepts:
  #   ["task1", "task2", ...]
  #   {"tasks": ["task1", ...]}                      (or "cloned"/"results"/"problems")
  #   {"tasks": [{"name": "task1", "status": "ok"}]}  (entries that look failed are skipped)
  # Returns nil (never raises) if no recognizable task list is found, so the
  # caller can fall back to an actionable error instead of a stack trace.
  def manifest_task_names(raw)
    list = raw.is_a?(Array) ? raw : %w[tasks cloned results problems].map { |k| raw[k] }.find { |v| v.is_a?(Array) }
    return nil unless list

    list.filter_map do |item|
      next item if item.is_a?(String)
      next unless item.is_a?(Hash)

      failed = [item['status'] == 'error', item['success'] == false, item['error'].present?].any?
      next if failed

      item['name'] || item['task'] || item['task_name'] || item['problem']
    end
  end

  # ALL = every task named in the newest tmp/cms_clone_all_*.json bulk-clone
  # manifest, if one exists. Deliberately simple: no attempt to reverse
  # -engineer "which local Problems came from CMS" by any other heuristic
  # (name matching against the live server, tagging, etc.) -- if there's no
  # manifest yet, the caller is told to validate tasks by name instead.
  def cloned_task_names_from_manifest
    files = Dir.glob(Rails.root.join('tmp', 'cms_clone_all_*.json').to_s)
    return nil if files.empty?

    newest = files.max_by { |f| File.mtime(f) }
    names = manifest_task_names(JSON.parse(File.read(newest)))
    if names.blank?
      warn "WARNING: no recognizable task list inside #{newest} -- ignoring it."
      return nil
    end
    puts "Using bulk-clone manifest #{File.basename(newest)} (#{names.size} task(s))."
    names
  rescue JSON::ParserError => e
    warn "WARNING: could not parse #{newest}: #{e.message} -- ignoring it."
    nil
  end

  def web_host_reachable?(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port, open_timeout: 3, read_timeout: 5) { |http| http.head('/') }
    true
  rescue StandardError
    false
  end

  # Streams extract_submissions.py to the CMS host over ssh (identical shape
  # to cms:clone's extraction of extract_task.py), captures fd 1 (the JSON
  # payload) and returns it parsed. [cms] stderr lines are echoed live via
  # warn as they arrive, same convention as cms:clone.
  def extract_sample(host:, python:, script_path:, task_name:, limit:)
    cmd = ['ssh', '-o', 'BatchMode=yes', host, 'sudo', '-n', '-u', 'cms', python, '-', task_name, limit.to_s]
    out = +''
    status = nil
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait|
      stdin.write(File.read(script_path))
      stdin.close
      err_thread = Thread.new { stderr.each_line { |l| warn "  [cms] #{l.chomp}" } }
      out = stdout.read
      err_thread.join
      status = wait.value
    end
    raise "extraction failed for '#{task_name}' (see [cms] lines above)" unless status&.success?

    JSON.parse(out)
  end
end

namespace :cms do
  desc 'CMS-source submission-replay validation (Mode B). ' \
       'Usage: rails "cms:validate[<task_name_or_ALL>,<per_band_limit=2>]"'
  task :validate, %i[task_or_all per_band_limit] => :environment do |_t, args|
    target = args[:task_or_all].to_s
    limit  = args[:per_band_limit].presence&.to_i || 2
    if target.blank?
      abort 'Usage: rails "cms:validate[<task_name_or_ALL>,<per_band_limit=2>]" ' \
            '(ALL = every task in the newest tmp/cms_clone_all_*.json bulk-clone manifest; ' \
            'per_band_limit defaults to 2, i.e. up to ~10 submissions per task across 5 score bands)'
    end
    Current.actor_note = "Rake: cms:validate[#{target},#{limit}]"

    cfg_file = Rails.root.join('config', 'cms_remote.yml')
    cfg = File.exist?(cfg_file) ? YAML.safe_load(File.read(cfg_file), symbolize_names: true) : {}
    host   = ENV['CMS_SSH_HOST'] || cfg[:host]
    python = ENV['CMS_REMOTE_PYTHON'] || cfg[:python] || '/home/cms/cms_venv/bin/python3'
    abort 'Set CMS_SSH_HOST or create config/cms_remote.yml (see config/cms_remote.yml.sample)' if host.blank?

    task_names =
      if target == 'ALL'
        names = CmsValidateSupport.cloned_task_names_from_manifest
        if names.blank?
          abort <<~MSG
            No usable bulk-clone manifest found (tmp/cms_clone_all_*.json) for ALL.
            Either run the bulk clone first, or validate tasks one at a time:
              rails "cms:validate[<task_name>]"
          MSG
        end
        names
      else
        [target]
      end
    task_names.each do |name|
      abort "Task name '#{name}' contains unsupported characters" unless name.to_s.match?(/\A[\w.\-]+\z/)
    end

    # Pre-flight: grade_sync fetches testcases over HTTP from this host, so
    # a validation sweep against a dead web app would fail every single
    # submission with the same confusing error -- catch it up front instead.
    web_url = Rails.configuration.worker[:hosts][:web]
    unless CmsValidateSupport.web_host_reachable?(web_url)
      abort "Web app not reachable at #{web_url} -- the judge fetches testcases over HTTP and needs " \
            'it running. Start the dev server: bin/rails server -p 3000'
    end

    script_path = Rails.root.join('script', 'cms_extract', 'extract_submissions.py')
    results = []
    task_names.each do |name|
      problem = Problem.find_by(name: name)
      unless problem
        puts "#{name}: SKIP (no local Problem named '#{name}' -- clone it first with cms:clone)"
        results << { task: name, skipped: true, reason: 'not cloned locally' }
        next
      end

      begin
        puts "#{name}: extracting sample (limit #{limit}/band) from #{host} ..."
        data = CmsValidateSupport.extract_sample(host: host, python: python, script_path: script_path,
                                                  task_name: name, limit: limit)
        report = Replay::CmsReplay.run(problem, data)
        results << report
        verdict = report[:mismatch].to_i.positive? ? 'FAIL' : 'ok'
        puts format('  %-28<task>s %-4<verdict>s replayed=%-3<replayed>d exact=%-3<exact>d ' \
                    'benign=%-3<benign>d mismatch=%-3<mismatch>d errored=%-3<errored>d score_exact=%<score_exact>d',
                    task: name, verdict: verdict, replayed: report[:replayed], exact: report[:exact],
                    benign: report[:benign], mismatch: report[:mismatch], errored: report[:errored],
                    score_exact: report[:score_exact])
      rescue StandardError => e
        warn "  #{name}: ERROR #{e.message}"
        results << { task: name, error: e.message }
      end
    end

    failed  = results.select { |r| r[:mismatch].to_i.positive? }.map { |r| r[:task] }
    errored = results.select { |r| r[:error] }.map { |r| r[:task] }

    puts "\n=== cms:validate summary ==="
    puts "tasks: #{results.size}  FAIL (mismatch > 0): #{failed.size}  errored: #{errored.size}"
    puts "FAILED tasks: #{failed.any? ? failed.join(', ') : 'none'}"
    puts "ERRORED tasks (could not complete): #{errored.join(', ')}" if errored.any?

    out_path = Rails.root.join('tmp', "cms_validate_#{Time.zone.now.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(out_path, JSON.pretty_generate({ generated_at: Time.zone.now.iso8601, target: target,
                                                per_band_limit: limit, failed_tasks: failed,
                                                errored_tasks: errored, results: results }))
    puts "Full report: #{out_path}"

    abort "cms:validate FAILED -- #{failed.size} task(s) with real mismatches: #{failed.join(', ')}" if failed.any?
  end
end
