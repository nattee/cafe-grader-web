# Near-Miss Grading batch instrument (v1 — CLI only).
# Spec: docs/superpowers/specs/2026-07-30-near-miss-grading-design.md
namespace :near_miss do
  desc <<~DESC
    Run bounded LLM repair over a contest's failing submissions.
    Usage: rake near_miss:repair CONTEST=<id> [PROBLEM=<id>] [SUBMISSION=<id>]
             [SCOPE=latest|all] [MIN_SCORE=] [MAX_SCORE=] [BUDGET_LINES=2]
             [BUDGET_CHARS=20] [ROUNDS=3] [SERVICE=<self-host key>] [RUN=<label>]
             [LIMIT=<n>] [DRY=1]
  DESC
  task repair: :environment do
    abort 'CONTEST=<id> or SUBMISSION=<id> is required' if ENV['CONTEST'].blank? && ENV['SUBMISSION'].blank?

    budget_lines = (ENV['BUDGET_LINES'].presence || 2).to_i
    budget_chars = (ENV['BUDGET_CHARS'].presence || 20).to_i
    rounds       = (ENV['ROUNDS'].presence || 3).to_i
    scope        = ENV['SCOPE'].presence || 'latest'
    model_key    = ENV['SERVICE'].presence
    abort "SCOPE must be latest|all, got #{scope}" unless %w[latest all].include?(scope)

    if ENV['SUBMISSION'].present?
      target_ids = [Submission.regular.find(ENV['SUBMISSION']).id]
      run_label  = ENV['RUN'].presence || "sub#{target_ids.first}-#{Time.zone.today}"
    else
      contest = Contest.find(ENV['CONTEST'])
      problems = contest.problems
      problems = problems.where(id: ENV['PROBLEM']) if ENV['PROBLEM'].present?
      target_ids = SubmissionRepair.batch_targets(
        problems: problems, users: contest.users, scope: scope,
        min_score: ENV['MIN_SCORE'].presence, max_score: ENV['MAX_SCORE'].presence)
      run_label = ENV['RUN'].presence || "contest#{contest.id}-#{Time.zone.today}"

      skipped_raw_sum = problems.joins('LEFT JOIN datasets live_ds ON live_ds.id = problems.live_dataset_id')
                                .where('live_ds.score_type = ? OR live_ds.id IS NULL', Dataset.score_types[:raw_sum])
      if skipped_raw_sum.any?
        puts "NOTE: skipped problems (raw_sum scoring or no live dataset — no defined full score): " \
             "#{skipped_raw_sum.pluck(:name).join(', ')}"
      end
    end

    target_ids = target_ids.first(ENV['LIMIT'].to_i) if ENV['LIMIT'].present?

    puts "Near-Miss repair batch"
    puts "  run label:  #{run_label}"
    puts "  targets:    #{target_ids.size} submissions"
    puts "  budget:     #{budget_lines} lines / #{budget_chars} chars, rounds: #{rounds}"
    puts "  service:    #{model_key || '(self_hosted_default)'}"

    if ENV['DRY'].present?
      by_problem = Submission.where(id: target_ids).joins(:problem).group('problems.name').count
      by_problem.each { |name, n| puts "    #{name}: #{n}" }
      puts 'DRY run — nothing enqueued.'
      next
    end

    # Model-identity guard (spec section 8.1): abort before enqueueing if the
    # endpoint serves a different model than configured. Only for self-host
    # services; a missing/blank service key will fail in the job instead.
    if Rails.configuration.llm[:self_hosted_models].present?
      chat = Llm::SelfHostChat.new(model_key: model_key)
      chat.verify_model!
      puts "  verified:   #{chat.model_key} serves #{chat.model_name}"
    end

    result = SubmissionRepair.enqueue_batch!(
      submission_ids: target_ids, budget_lines: budget_lines,
      budget_chars: budget_chars, rounds: rounds, run_label: run_label,
      model_key: model_key)
    puts "enqueued #{result[:enqueued]}, skipped #{result[:skipped]} (already attempted in this run label)"
    puts "watch progress: SubmissionRepair.where(run_label: '#{run_label}').group(:status).count"
  end
end
