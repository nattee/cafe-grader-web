require 'json'

module Replay
  # CMS-source submission-replay validation ("Mode B", doc/CMS-Migration.md
  # Sec 3): grades a sample of a task's REAL CMS submissions through cafe's
  # real judge, against the cloned problem, and diffs each fresh grade
  # against CMS's recorded result -- CMS's grades are the oracle. Dev
  # diagnostic only; never touches CMS itself (the extraction side,
  # script/cms_extract/extract_submissions.py, is read-only against CMS).
  #
  # DEVIATION from a literal read of the design brief, recorded here because
  # it is load-bearing: the brief said to diff `cms_verdict_string(...)`
  # directly against `res[:grader_comment]` via Replay::ReplayDiff.classify.
  # Verified empirically against a real cloned problem
  # (mar2025_eatingfish, dev problem 717, group_min with multi-testcase
  # groups): `Scorer#build_grading_text` brackets each multi-testcase group
  # -- e.g. `"[-------][------]..."` , 54 chars for 42 testcases -- so
  # `submission.grader_comment` is NOT one-char-per-testcase for group_min
  # datasets with grouped testcases (the norm for this CMS archive; see
  # doc/CMS-Migration.md Sec 1). Diffing that bracketed string
  # position-by-position against the flat CMS-derived string would report
  # every such submission as `:structural` (length mismatch) regardless of
  # correctness -- exactly the noise Tier 1 exists to avoid. Fix: build BOTH
  # sides of the diff the same way, from the SAME `dataset.testcases.order(:num)`
  # walk (`cms_verdict_string` for the oracle, `cafe_verdict_string` for the
  # fresh grade, reading `Evaluation#result` directly rather than the
  # display-formatted grader_comment column) -- lengths and positions are
  # then equal by construction. Replay::ReplayDiff.classify itself is reused
  # completely unchanged, exactly as directed.
  module CmsReplay
    module_function

    # CMS's canonical Submission#language string -> cafe Language#name.
    # Sourced from cms.grading.languagemanager.LANGUAGES on c2 (CMS
    # 1.4.dev3) crossed with Language.seed's cafe-side names. A CMS language
    # with no cafe equivalent, or nil/unrecognised, is a per-submission
    # error (bucketed as errored) -- never a silent guess.
    CMS_LANGUAGE_MAP = {
      'C++11 / g++'         => 'cpp',
      'C11 / gcc'           => 'c',
      'Pascal / fpc'        => 'pas',
      'Python 2 / CPython'  => 'python',
      'Python 3 / CPython'  => 'python',
      'Java / JDK'          => 'java',
      'Java 1.4 / gcj'      => 'java',
      'PHP'                 => 'php',
      'Haskell / ghc'       => 'haskell',
      'Rust'                => 'rust'
    }.freeze

    # Score band within which cms_score and cafe points are still
    # considered "score_exact" -- absorbs float arithmetic noise between
    # CMS's (Python) and cafe's (Ruby BigDecimal) score-type math, not real
    # disagreement.
    SCORE_EPSILON = 0.01

    # Translates one CMS per-testcase evaluation (outcome + text) into
    # cafe's verdict char (see CLAUDE.md's Submission#grader_comment
    # legend). Order matters: full credit short-circuits before text is
    # even inspected; a zero/partial outcome then falls through to
    # text-pattern TLE/MLE detection -- CMS reports both with outcome 0.0
    # and a text explaining why (verified against cms/grading/steps/
    # evaluation.py on the live server: "Execution timed out[...]" and
    # "Execution killed [...]") -- before defaulting to partial/wrong.
    def verdict_char(outcome, text)
      outcome = outcome.to_f
      return 'P' if outcome >= 1.0

      t = text.to_s
      return 'T' if t.match?(/timed out/i)
      return 'x' if t.match?(/killed|memory/i)
      return 's' if outcome > 0

      '-'
    end

    # Builds the CMS-oracle grading string: one char per testcase, walking
    # +dataset+'s testcases in `num` order and mapping each `code_name`
    # through +evaluations+ (a codename => {outcome:, text:} hash, as
    # produced by extract_submissions.py). A codename present in the
    # dataset but missing from +evaluations+ is a hard error -- report it,
    # never silently pad (a short/padded string would corrupt every
    # position after the gap).
    def cms_verdict_string(evaluations, dataset)
      evaluations ||= {}
      dataset.testcases.order(:num).map do |tc|
        ev = evaluations[tc.code_name] || evaluations[tc.code_name.to_s]
        if ev.nil?
          raise "missing CMS evaluation for codename #{tc.code_name.inspect} (testcase ##{tc.num})"
        end

        verdict_char(ev['outcome'] || ev[:outcome], ev['text'] || ev[:text])
      end.join
    end

    # Builds the cafe-fresh grading string using the identical walk order as
    # cms_verdict_string (so positions line up by construction, regardless
    # of how Scorer#build_grading_text groups/brackets its own display
    # string) -- reads Evaluation#result directly via cafe's own
    # RESULT_CODE mapping. '?' (waiting) marks a testcase with no
    # evaluation row at all, which should not happen for a `done` submission.
    def cafe_verdict_string(submission, dataset)
      evals_by_tc = submission.evaluations.index_by(&:testcase_id)
      dataset.testcases.order(:num).map do |tc|
        ev = evals_by_tc[tc.id]
        ev ? Evaluation.result_enum_to_code(ev.result) : '?'
      end.join
    end
    private_class_method :cafe_verdict_string

    # Runs Mode B for one +problem+ against a sample produced by
    # extract_submissions.py (+sample_json+: a JSON string OR an
    # already-parsed Hash with "task"/"dataset_id"/"submissions" keys).
    # Grades each sampled submission for real (ReplayGrader.grade_sync
    # against the real judge -- requires the web app reachable at
    # Rails.configuration.worker[:hosts][:web], since the judge fetches
    # testcases over HTTP; that failure is never swallowed here, it just
    # raises out of grade_sync and gets bucketed per-submission as errored,
    # so a systemic outage shows up as every submission erroring rather than
    # a silent skip).
    #
    # Returns a report Hash: task, replayed, exact, benign, mismatch,
    # errored, score_exact, mismatch_details (cms id, cms score, cafe
    # points, both verdict strings, first differing codenames).
    def run(problem, sample_json, deadline: 700)
      data = sample_json.is_a?(String) ? JSON.parse(sample_json) : sample_json
      submissions = (data['submissions'] || data[:submissions] || []).to_a

      report = { task: data['task'] || data[:task], replayed: 0, exact: 0, benign: 0,
                mismatch: 0, errored: 0, score_exact: 0, mismatch_details: [], error_details: [] }

      dataset = problem.live_dataset
      unless dataset
        report[:errored] = submissions.size
        submissions.each do |raw|
          entry = normalize_entry(raw)
          report[:error_details] << { cms_submission_id: entry['cms_submission_id'],
                                      error: "problem '#{problem.name}' has no live dataset" }
        end
        return report
      end

      bot = Replay::SubmissionReplay.replay_bot
      begin
        submissions.each { |raw| replay_one(report, problem, dataset, bot, normalize_entry(raw), deadline) }
      ensure
        GraderProcess.where(box_id: Replay::ReplayGrader::REPLAY_BOX_ID,
                            worker_id: Replay::ReplayGrader::REPLAY_WORKER_ID).delete_all
      end
      report
    end

    def normalize_entry(raw)
      raw.is_a?(Hash) ? raw.transform_keys(&:to_s) : raw
    end
    private_class_method :normalize_entry

    def replay_one(report, problem, dataset, bot, entry, deadline)
      fresh = nil
      begin
        language = language_for(entry['language'])
        cms_gc = cms_verdict_string(entry['evaluations'], dataset)

        fresh = Submission.new(user: bot, problem: problem, language: language,
                               source_filename: "cms_#{entry['cms_submission_id']}.#{language.ext}",
                               submitted_at: Time.zone.now, tag: :default)
        fresh.source = entry['source']
        fresh.save!(validate: false) # replaying an already-accepted CMS source; skip submit-auth validation

        res = Replay::ReplayGrader.grade_sync(fresh, dataset, deadline: deadline)
        cafe_gc = cafe_verdict_string(fresh, dataset)
        diff = Replay::ReplayDiff.classify(cms_gc, entry['cms_score'], cafe_gc, res[:points])
        tally(report, diff, entry, res, cms_gc, cafe_gc, dataset)
      rescue StandardError => e
        report[:errored] += 1
        report[:error_details] << { cms_submission_id: entry['cms_submission_id'], error: e.message }
      ensure
        # Judge Job rows reference the submission by integer `arg` (no FK), so
        # they are NOT cascade-destroyed with the submission -- delete them here.
        if fresh
          Job.where(arg: fresh.id).delete_all
          fresh.destroy
        end
        report[:replayed] += 1
      end
    end
    private_class_method :replay_one

    def language_for(cms_language)
      name = CMS_LANGUAGE_MAP[cms_language]
      raise "unsupported/unmapped CMS language #{cms_language.inspect}" if name.nil?

      language = Language.find_by(name: name)
      raise "cafe has no Language named #{name.inspect}" unless language

      language
    end
    private_class_method :language_for

    def tally(report, diff, entry, res, cms_gc, cafe_gc, dataset)
      # cms_gc and cafe_gc are always the same length (both built by mapping
      # the identical dataset.testcases.order(:num) walk), so :structural
      # (length mismatch) should be unreachable here -- fold it into
      # :mismatch defensively rather than dropping it on the floor.
      key = diff[:verdict] == :structural ? :mismatch : diff[:verdict]
      report[key] += 1

      cms_score = entry['cms_score'].to_f
      cafe_points = res[:points].to_f
      report[:score_exact] += 1 if (cms_score - cafe_points).abs < SCORE_EPSILON

      return unless key == :mismatch

      report[:mismatch_details] << {
        cms_submission_id: entry['cms_submission_id'],
        cms_score: entry['cms_score'],
        cafe_points: res[:points],
        cms_verdict: cms_gc,
        cafe_verdict: cafe_gc,
        diff_codenames: diff_codenames(diff[:positions], dataset),
        note: diff[:note]
      }
    end
    private_class_method :tally

    def diff_codenames(positions, dataset, limit: 8)
      return [] if positions.blank? || dataset.nil?

      ordered = dataset.testcases.order(:num).pluck(:code_name)
      positions.first(limit).map { |p| ordered[p[:i]] || "idx#{p[:i]}" }
    end
    private_class_method :diff_codenames
  end
end
