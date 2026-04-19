class VivaTurn < ApplicationRecord
  enum :role, {system: 0, assistant: 1, student: 2}
  enum :status, {ok: 0, processing: 1, error: 2}

  belongs_to :submission

  validates :content, presence: true, if: -> { student? || (assistant? && ok?) }
  validates :sequence, presence: true, uniqueness: {scope: :submission_id}

  scope :ordered, -> { order(:sequence) }
  scope :assistant_turns, -> { where(role: :assistant) }

  before_validation :assign_sequence_if_blank, on: :create

  def self.cost_summary_for(submissions)
    where(submission_id: submissions).assistant_turns.sum(:cost) || 0.0
  end

  private

  def assign_sequence_if_blank
    return if sequence.present?
    return unless submission

    submission.with_lock do
      self.sequence = (submission.viva_turns.maximum(:sequence) || -1) + 1
    end
  end
end
