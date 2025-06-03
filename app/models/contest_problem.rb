class ContestProblem < ApplicationRecord
  self.table_name = 'contests_problems'
  belongs_to :contest
  belongs_to :problem
end
