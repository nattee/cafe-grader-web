class ContestProblem < ApplicationRecord
  self.table_name = 'contests_problems'
  belongs_to :contest
  belongs_to :problem

  # scope with available problems in contest mode for that user
  scope :from_available_contests_problems_for_user, ->(user_id) {
    where(problem: Problem.contests_problems_for_user(user_id))
  }
end
