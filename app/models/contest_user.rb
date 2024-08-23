class ContestUser < ApplicationRecord
  self.table_name = 'contests_users'
  belongs_to :contest
  belongs_to :user
end
