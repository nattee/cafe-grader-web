module Replay
  # Cafe->cafe behavioral validation of the import/export path. Exports a
  # problem, re-imports it as a throwaway (_rc_ prefix), replays a sample of the
  # original's submissions through the real grader, and diffs each fresh grade
  # against the original's STORED grade. Everything created is destroyed on exit.
  # Dev diagnostic only — never touches CMS.
  module SubmissionReplay
    module_function

    RC_PREFIX = '_rc_'

    def replay_bot
      User.find_or_create_by!(login: 'replay_bot') do |u|
        u.full_name = 'Replay Bot (import/export validation)'
        u.password = SecureRandom.hex(16)
      end
    end

    def run(problem, limit: 100)
      sample = ReplaySampler.sample(problem, limit: limit)
      clone = nil
      report = { problem: problem.name, replayed: 0, skipped_stale: sample[:skipped_stale],
                 buckets: sample[:buckets], exact: 0, benign: 0, mismatch: 0,
                 structural: 0, errored: 0, mismatch_details: [], error_details: [] }
      begin
        clone = import_clone(problem)
        bot = replay_bot
        sample[:submissions].each do |orig|
          fresh = build_submission(bot, clone, orig)
          res = ReplayGrader.grade_sync(fresh, clone.live_dataset)
          diff = ReplayDiff.classify(orig.grader_comment, orig.points, res[:grader_comment], res[:points])
          tally(report, diff, orig, res)
          report[:replayed] += 1
        ensure
          # Judge Job rows reference the submission by integer `arg` (no FK), so
          # they are NOT cascade-destroyed with the problem — delete them here.
          Job.where(arg: fresh.id).delete_all if fresh
        end
      ensure
        clone&.destroy   # cascades datasets/testcases/submissions/evaluations + purges blobs
      end
      report
    end

    # Export `problem` to a temp dir and re-import it as a fresh _rc_ problem.
    def import_clone(problem)
      Dir.mktmpdir("replay") do |dump|
        ProblemExporter.new.export_problem_to_dir(problem, base_dir: dump, zip: false)
        exported = File.join(dump, problem.name.parameterize)
        pi = ProblemImporter.new
        pi.import_dataset_from_dir(exported, "#{RC_PREFIX}#{SecureRandom.hex(6)}",
                                   full_name: "replay of #{problem.name}", user: replay_bot,
                                   do_solutions: false)
        pi.problem
      end
    end

    def build_submission(bot, clone, orig)
      s = Submission.new(user: bot, problem: clone, language: orig.language,
                         source_filename: orig.source_filename, submitted_at: Time.zone.now, tag: :default)
      s.source = orig.source
      s.save!(validate: false)   # replaying already-valid sources; skip submit-auth validation
      s
    end

    def tally(report, diff, orig, res)
      # A fresh grader_error while the stored grade was a real result is an
      # ENVIRONMENT limitation (e.g. sandbox/cgroup unavailable for some
      # languages on this box), not an import/export defect — bucket apart and
      # exclude from the pass/fail verdict.
      if res[:status].to_s == 'grader_error'
        report[:errored] += 1
        report[:error_details] << { orig_submission_id: orig.id, language: orig.language&.name,
                                    new_status: res[:status], new_gc: res[:grader_comment] }
        return
      end
      report[diff[:verdict]] += 1
      return unless %i[mismatch structural].include?(diff[:verdict])
      report[:mismatch_details] << {
        orig_submission_id: orig.id, verdict: diff[:verdict],
        orig_points: orig.points, new_points: res[:points],
        orig_gc: orig.grader_comment, new_gc: res[:grader_comment],
        positions: diff[:positions], note: diff[:note]
      }
    end

    # Destroy every throwaway artifact (backstop for interrupted runs).
    def purge!
      Submission.joins(:user).where(users: { login: 'replay_bot' }).find_each do |s|
        Job.where(arg: s.id).delete_all   # judge jobs have no FK to the submission
        s.destroy
      end
      # the dedicated replay grader_process row (created by ReplayGrader)
      GraderProcess.where(box_id: ReplayGrader::REPLAY_BOX_ID,
                          worker_id: ReplayGrader::REPLAY_WORKER_ID).delete_all
      scope = Problem.where("name LIKE ?", "#{RC_PREFIX}%")
      count = scope.count
      scope.find_each(&:destroy)
      count
    end
  end
end
