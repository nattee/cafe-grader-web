namespace :engine do
  desc 'Grade one existing submission end to end on this host (real isolate), report, then restore it. SUB=<id>|auto [BOX=99]'
  task smoke: :environment do
    sub_id = ENV['SUB'] or abort 'usage: bin/rails engine:smoke SUB=<submission id>|auto [BOX=99]   (pick a submission you are happy to see re-evaluated, or SUB=auto to let EngineSmokePicker choose; its stored grade is restored afterwards)'
    box = Integer(ENV.fetch('BOX', '99'))
    fmt = ->(g) { "#{g[:status]} points=#{g[:points]} comment=#{g[:grader_comment].inspect}" }

    if sub_id == 'auto'
      # The deploy pipeline's mode. Two SKIPPED exits (0) are deliberate: a
      # web-only host grades nothing, and a fresh host has nothing to regrade;
      # neither should block a deploy. An explicit SUB=<id> never skips.
      worker_id = Rails.configuration.worker[:worker_id]
      if GraderProcess.where(worker_id: worker_id, enabled: true).none?
        puts "SKIPPED: no enabled grader boxes for worker #{worker_id} on this host — nothing grades here, nothing to smoke"
        exit 0
      end
      picker = EngineSmokePicker.new
      sub = picker.pick
      unless sub
        puts 'SKIPPED: no suitable submission on this host — need done, regular, non-viva, full score, ' \
             "#{EngineSmokePicker::LANGUAGE_ORDER.join('/')}, graded after its live dataset last changed, " \
             "slowest testcase within #{(EngineSmokePicker::RUNTIME_MARGIN * 100).to_i}% of the time limit, " \
             "testcases x limit <= #{EngineSmokePicker::MAX_BUDGET_SECONDS}s"
        exit 0
      end
      puts "auto-picked submission #{sub.id}: #{picker.describe(sub)}"
    else
      sub = Submission.find(Integer(sub_id))
    end

    report = EngineSmoke.new(sub, box_id: box).run

    puts "submission #{report.submission_id}: #{sub.language.name}, problem #{sub.problem_id} #{sub.problem.name}, dataset #{report.dataset_id}, box #{box}"
    puts "  stored grade: #{fmt.call(report.before)}"
    report.evaluations.each { |e| puts "  tc #{e[:testcase_id]}: #{e[:result]} score=#{e[:score]} time=#{e[:time]}ms" }
    puts "  this run:     #{fmt.call(report.after)}"
    if report.error
      puts "  ERROR #{report.error.class}: #{report.error.message}"
      puts report.error.backtrace.first(6).map { |l| "    #{l}" }
      puts '  submission restored to its stored grade'
      exit 1
    end
    identical = %i[status points grader_comment].all? { |k| report.before[k].to_s == report.after[k].to_s }
    puts(identical ? '  verdict identical to the stored grade' : '  verdict DIFFERS from the stored grade — check the dataset has not changed since, then investigate')
    puts '  submission restored to its stored grade'
    exit 2 unless identical
  end
end
