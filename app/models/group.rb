class Group < ActiveRecord::Base
  has_many :groups_problems, class_name: 'GroupProblem'
  has_many :problems, :through => :groups_problems

  has_many :groups_users, class_name: 'GroupUser'
  has_many :users, :through => :groups_users

  #has_and_belongs_to_many :problems
  #has_and_belongs_to_many :users

  def add_users_skip_existing(users_list)
    new_list = []
    users_list.each do |u|
      new_list << u unless users.include? u
    end
    users << new_list
  end

end

