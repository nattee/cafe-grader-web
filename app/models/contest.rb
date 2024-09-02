class Contest < ApplicationRecord

  has_many :contests_users, class_name: 'ContestUser'
  has_many :contests_problems, class_name: 'ContestProblem'
  has_many :users, through: :contests_users
  has_many :problems, through: :contests_problems

  scope :enabled, -> { where(enabled: true) }

  # new_users are active record relation
  # return a toast reaponse hash

  delegate :pluralize, to: 'ActionController::Base.helpers'

  def add_users(new_users)
    return {title: 'Contest users are NOT changed', body: 'No new users given.'} if new_users.count == 0

    # remove already existing users
    to_be_added = new_users.where.not(id: self.users)
    num_actual_add = to_be_added.count
    num_request_add = new_users.count


    self.users << to_be_added
    if num_actual_add == 0
      return {title: 'Contest users are NOT changed', body: 'All users given are already in the contest.'}
    elsif num_actual_add == num_request_add
      return {title: 'Contest users changed', body: "All given #{pluralize num_actual_add, 'user'} were added to the contest."}
    else
      return {title: 'Contest users changed',
              body: %Q"
                From given #{pluralize num_request_add,'user'},
                #{pluralize num_actual_add, 'user'} were added to the contest
                while the other #{pluralize (num_request_add - num_actual_add), 'user'} are already in the contest.
              "}
    end

  end

  def add_problems(new_problems)
    return {title: 'Contest problems are NOT changed', body: 'No new problems given.'} if new_problems.count == 0

    # remove already existing problems
    to_be_added = new_problems.where.not(id: self.problems)
    num_actual_add = to_be_added.count
    num_request_add = new_problems.count


    self.problems << to_be_added
    if num_actual_add == 0
      return {title: 'Contest problems are NOT changed', body: 'All problems given are already in the contest.'}
    elsif num_actual_add == num_request_add
      return {title: 'Contest problems changed', body: "All given #{pluralize num_actual_add, 'problem'} were added to the contest."}
    else
      return {title: 'Contest problems changed',
              body: %Q"
                From given #{pluralize num_request_add,'problem'},
                #{pluralize num_actual_add, 'problem'} were added to the contest
                while the other #{pluralize (num_request_add - num_actual_add), 'problem'} are already in the contest.
              "}
    end

  end

end
