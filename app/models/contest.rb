class Contest < ApplicationRecord

  has_many :contests_users, class_name: 'ContestUser'
  has_many :contests_problems, class_name: 'ContestProblem'
  has_many :users, through: :contests_users
  has_many :problems, through: :contests_problems

  scope :enabled, -> { where(enabled: true) }

end
