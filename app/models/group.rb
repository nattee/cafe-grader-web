class Group < ApplicationRecord
  has_many :groups_problems, class_name: 'GroupProblem'
  has_many :problems, :through => :groups_problems

  has_many :groups_users, class_name: 'GroupUser'
  has_many :users, :through => :groups_users

  scope :editable_by_user, -> (user_id) {
    joins(:groups_users).where(groups_users: { user_id: user_id, enabled: true, role: 'editor' })
  }

  scope :reportable_by_user, -> (user_id) {
    joins(:groups_users).where(groups_users: { user_id: user_id, enabled: true, role: ['editor','reporter'] })
  }

  scope :submittable_by_user, -> (user_id) {
    joins(:groups_users).where(groups_users: { user_id: user_id, enabled: true })
  }
  
  scope :enabled, -> { where(enabled: true) }

  #has_and_belongs_to_many :problems
  #has_and_belongs_to_many :users

  def add_users_skip_existing(users_list)
    new_list = []
    users_list.uniq.each do |u|
      new_list << u unless users.include? u
    end
    users << new_list
  end

end

