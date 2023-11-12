class GroupUser < ApplicationRecord
  self.table_name = 'groups_users'

  enum role: {user: 0, editor: 1}

  belongs_to :user
  belongs_to :group
  validates_uniqueness_of :user_id, scope: :group_id, message: ->(object, data) { "'#{User.find(data[:value]).full_name}' is already in the group" }
end
