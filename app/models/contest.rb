class Contest < ApplicationRecord

  has_and_belongs_to_many :users
  has_and_belongs_to_many :problems

  scope :enabled, -> { where(enabled: true) }

end
