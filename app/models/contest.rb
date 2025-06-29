class Contest < ApplicationRecord

  has_many :contests_problems, class_name: 'ContestProblem', dependent: :destroy
  has_many :contests_users, class_name: 'ContestUser', dependent: :destroy
  has_many :problems, through: :contests_problems
  has_many :users, through: :contests_users

  scope :enabled, -> { where(enabled: true) }
  # scope :active, -> (time = Time.zone.now) { where(enabled: true).where('start <= ? and stop >= ?',time,time)}

  scope :editable_by_user, -> (user_id) {
    joins(:contests_users).where(contests_users: { user_id: user_id, enabled: true, role: 'editor' })
  }

  scope :submittable_by_user, -> (user_id) {
    joins(:contests_users).where(contests_users: { user_id: user_id, enabled: true })
  }

  # new_users are active record relation
  # return a toast reaponse hash

  # need pluralize helper function
  delegate :pluralize, to: 'ActionController::Base.helpers'

  # return an ActiveRecord relation of users that is submittable for this con
  def submittable_users(current_time = Time.zone.now)
    return User.none unless enabled?
    user_ids = contests_users.where(enabled: true).where('IFNULL(extra_time_second) >= ?', current_time - self.stop).pluck :user_id
    Users.where(id: user_ids, enabled: true)
  end

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

  def add_users_from_csv(lines)
    error_logins = []
    first_error = nil
    added_users = []

    lines.split("\n").each do |line|
      #split with large limit, this will cause consecutive ',' to be result in a blank instead of nil
      items = line.chomp.split(',',1000)

      login = items[0]
      remark = items.length >= 2 ? items[1] : nil
      seat = items.length >= 3 ? items[2] : nil

      user = User.where(login: login).first
      
      unless user
        error_logins << "'#{login}'"
        next
      end

      cu = self.contests_users.find_or_create_by(user: user)

      cu.remark = remark if remark
      cu.seat = seat if seat

      if cu.save
        added_users << user
      else
        error_logins << "'#{login}'"
        first_error = user.errors.full_messages.to_sentence unless first_error
      end
    end

    return {error_logins: error_logins, first_error: first_error, added_users:  added_users}
  end

  def add_problems_and_assign_number(new_problems)
    return {title: 'Contest problems are NOT changed', body: 'No new problem given.'} if new_problems.count == 0

    # remove already existing problems
    to_be_added = new_problems.where.not(id: self.problems)
    num_actual_add = to_be_added.count
    num_request_add = new_problems.count

    latest_num = self.contests_problems.maximum(:number) || 1
    to_be_added.ids.each do |new_prob_id|
      contests_problems.create(problem_id: new_prob_id,number: latest_num)
      latest_num += 1
    end

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

  # set the number of the problem to *number* and rearrage other
  def set_problem_number(problem,number)
    num = 1
    self.contests_problems.where.not(problem_id: problem.id).order(:number).each do |cp,idx|
      offset = (num) >= number ? 1 : 0
      cp.update(number: num+offset)
      num += 1
    end
    self.contests_problems.where(problem_id: problem.id).first.update(number: [self.contests_problems.count,[1,number.round].max].min)
  end

  # return :later, :pre, :during, :post, :ended
  def contest_status
    current_time = Time.zone.now
    return :ended if current_time > self.stop
    return :later if current_time < self.start
    return :during
  end

  # check in interval in seconds
  def self.check_in_interval
    # once every minutes
    return 60
  end

  # return a submissions of this contests
  # this includes extra_time_second and start_offset_second as well
  def submissions
    Submission.joins(user: :contests_users)
      .where('contest_id = ?',self.id)
      .where(user: users, problem: problems)
      .where('submitted_at >= DATE_SUB(?,INTERVAL start_offset_second SECOND)',start)
      .where('submitted_at <= DATE_ADD(?,INTERVAL extra_time_second SECOND)',stop)
  end

  def user_submissions(user)
    cu = contests_users.where(user: user).take
    actual_start = start - cu.start_offset_second.second
    actual_stop = stop + cu.extra_time_second.second
    Submission.where(user: user, problem: problems)
      .where('submitted_at >= ?',actual_start)
      .where('submitted_at <= ?',actual_stop)
  end

  #
  # -------- report ---------------
  #
  def score_report
    # calculate submission with max score
    max_records = self.submissions
      .group('submissions.user_id,submissions.problem_id')
      .select('MAX(submissions.points) as max_score, submissions.user_id, submissions.problem_id')

    # records having the same score as the max record
    records = self.submissions.joins("JOIN (#{max_records.to_sql}) MAX_RECORD ON " +
                               'submissions.points = MAX_RECORD.max_score AND ' +
                               'submissions.user_id = MAX_RECORD.user_id AND ' +
                               'submissions.problem_id = MAX_RECORD.problem_id ').joins(:problem)
      .select('submissions.user_id,users_submissions.login,users_submissions.full_name,users_submissions.remark')
      .select('problems.name')
      .select('max_score')
      .select('submitted_at')
      .select('submissions.id as sub_id')
      .select('submissions.problem_id,submissions.user_id')


    return Submission.calculate_max_score(records,users,problems)
  end

  protected

  # this is refactored from the report controller
  #  *records* is a result from Contest.score_report
  #  *users* is the User relation that is used to build *records*
  #
  # return  a hash {score: xx, stat: yy}
  # xx is {
  #   #{user.login}: {
  #     id:, full_name:, remark:,
  #     prob_#{prob.name}:, time_#{prob.name}
  #     ...
  # }
  def self.build_score_result(records,users)

    # init score hash
    result = {score: Hash.new { |h,k| h[k] = {} }, 
              stat: Hash.new {|h,k| h[k] = { zero: 0, partial: 0, full: 0, sum: 0, score: [] } } }

    # populate users
    users.each { |u| result[:score][u.login] = {id: u.id, full_name: u.full_name, remark: u.remark} }

    # populate result
    records.each do |score|
      result[:score][score.user_id][score.problem_id] = score.max_score || 0
    end

    return result
  end


end
