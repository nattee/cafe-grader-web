# One row per Near-Miss repair attempt, including failures — "the LLM could
# not fix it within budget" is a data point for the study, not an error.
# Grading state/score of an accepted repair lives on the shadow Submission
# (repaired_submission), never duplicated here.
# See docs/superpowers/specs/2026-07-30-near-miss-grading-design.md.
class SubmissionRepair < ApplicationRecord
  enum :status, {pending: 0, processing: 1, accepted: 2, over_budget: 3, no_change: 4, failed: 5}

  FIX_CATEGORIES = %w[io_format parsing syntax boundary logic other].freeze

  belongs_to :original_submission, class_name: 'Submission'
  belongs_to :repaired_submission, class_name: 'Submission', optional: true

  serialize :rounds_log, coder: JSON, type: Array

  validates :budget_lines, :budget_chars, numericality: {greater_than: 0}
  validates :fix_category, inclusion: {in: FIX_CATEGORIES}, allow_nil: true

  # Batch target selection (rake near_miss:repair). Returns ids of
  # submissions eligible for repair:
  #  * regular (never repair a shadow), non-viva (spec D8), graded
  #  * "below full marks" = points < 100 on a non-raw_sum live dataset
  #    (the grader normalizes sum/group_min to 100; raw_sum problems have
  #    no defined full score and are skipped — mirror of the canonical
  #    activity_query pattern in report_controller.rb)
  #  * scope: 'latest' = latest submission per (user, problem), kept only
  #    if that latest one is below full; 'all' = every below-full submission
  def self.batch_targets(problems:, users:, scope: 'latest', min_score: nil, max_score: nil)
    base = Submission.regular
      .where(problem: problems, user: users)
      .where(status: [Submission.statuses[:done], Submission.statuses[:compilation_error]])
    viva_language = Language.find_by(name: 'viva')
    base = base.where.not(language: viva_language) if viva_language

    if scope == 'latest'
      last_ids = base.group(:user_id, :problem_id).pluck(Arel.sql('MAX(submissions.id)'))
      base = Submission.where(id: last_ids)
    end

    below_full = base
      .joins(:problem)
      .joins('LEFT JOIN datasets live_ds ON live_ds.id = problems.live_dataset_id')
      .where('live_ds.score_type IS NOT NULL AND live_ds.score_type <> ?', Dataset.score_types[:raw_sum])
      .where('submissions.points < 100')
    below_full = below_full.where('submissions.points >= ?', min_score) if min_score.present?
    below_full = below_full.where('submissions.points <= ?', max_score) if max_score.present?
    below_full.pluck(:id)
  end

  # Creates pending attempt rows and enqueues one repair job per target.
  # Idempotent per (original_submission, run_label): re-running the same
  # RUN label skips submissions that already have an attempt row, so a
  # crashed batch can be resumed by re-running the same command.
  def self.enqueue_batch!(submission_ids:, budget_lines:, budget_chars:, rounds:, run_label:, model_key: nil)
    enqueued = 0
    skipped  = 0
    submission_ids.each do |sid|
      if exists?(original_submission_id: sid, run_label: run_label)
        skipped += 1
        next
      end
      repair = create!(original_submission_id: sid, status: :pending,
                       budget_lines: budget_lines, budget_chars: budget_chars,
                       run_label: run_label)
      Llm::SubmissionRepairJob.perform_later(Submission.find(sid), repair: repair,
                                             rounds: rounds, model_key: model_key)
      enqueued += 1
    end
    {enqueued: enqueued, skipped: skipped}
  end
end
