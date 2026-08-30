namespace :engine do
  desc 'Grade one existing submission end to end on this host (real isolate), report, then restore it. SUB=<id> [BOX=99]'
  task smoke: :environment do
    sub_id = ENV['SUB'] or abort 'usage: bin/rails engine:smoke SUB=<submission id> [BOX=99]   (pick a submission you are happy to see re-evaluated; its stored grade is restored afterwards)'
    sub = Submission.find(Integer(sub_id))
    box = Integer(ENV.fetch('BOX', '99'))
    fmt = ->(g) { "#{g[:status]} points=#{g[:points]} comment=#{g[:grader_comment].inspect}" }

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
