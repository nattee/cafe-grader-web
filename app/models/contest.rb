class Contest < ApplicationRecord

  has_many :contests_users, class_name: 'ContestUser'
  has_many :contests_problems, class_name: 'ContestProblem'
  has_many :users, through: :contests_users
  has_many :problems, through: :contests_problems

  scope :enabled, -> { where(enabled: true) }
  scope :active, -> (time = Time.zone.now) { where(enabled: true).where('start <= ? and stop >= ?',time,time)}

  # new_users are active record relation
  # return a toast reaponse hash

  # need pluralize helper function
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

  #
  # -------- report ---------------
  #
  
  def score_report
    # calculate submission with max score
    max_records = Submission.in_range(:time,start,stop)
      .where(user: users, problem: problems)
      .group('user_id,problem_id')
      .select('MAX(submissions.points) as max_score, user_id, problem_id')

    # convert to score hash
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
