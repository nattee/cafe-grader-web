require 'digest/sha1'
require 'net/pop'
require 'net/https'
require 'net/http'
require 'json'

class User < ApplicationRecord

  has_and_belongs_to_many :roles

  #has_and_belongs_to_many :groups
  has_many :groups_users, class_name: 'GroupUser'
  has_many :groups, :through => :groups_users

  has_many :test_requests, -> {order(submitted_at: :desc)}

  has_many :messages, -> { order(created_at: :desc) },
           :class_name => "Message",
           :foreign_key => "sender_id"

  has_many :replied_messages, -> { order(created_at: :desc) },
           :class_name => "Message",
           :foreign_key => "receiver_id"

  has_many :logins

  has_many :submissions

  has_one :contest_stat, :class_name => "UserContestStat", :dependent => :destroy

  belongs_to :site, optional: true
  belongs_to :country, optional: true

  has_and_belongs_to_many :contests, -> { order(:name)}

  scope :activated_users, -> {where activated: true}

  validates_presence_of :login
  validates_uniqueness_of :login
  validates_format_of :login, :with => /\A[\_A-Za-z0-9]+\z/
  validates_length_of :login, :within => 3..30

  validates_presence_of :full_name
  validates_length_of :full_name, :minimum => 1

  validates_presence_of :password, :if => :password_required?
  validates_length_of :password, :within => 4..50, :if => :password_required?
  validates_confirmation_of :password, :if => :password_required?

  validates_format_of :email,
                      :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i,
                      :if => :email_validation?
  validate :uniqueness_of_email_from_activated_users,
           :if => :email_validation?
  validate :enough_time_interval_between_same_email_registrations,
           :if => :email_validation?

  # these are for ytopc
  # disable for now
  #validates_presence_of :province

  attr_accessor :password

  before_save :encrypt_new_password
  before_save :assign_default_site
  before_save :assign_default_contest

  # this is for will_paginate
  cattr_reader :per_page
  @@per_page = 50

  def self.authenticate(login, password)
    user = find_by_login(login)
    if user
      return user if user.authenticated?(password)
      if user.authenticated_by_cucas?(password)
        user.password = password
        user.save
        return user
      end

    end
  end


  def authenticated_by_cucas?(password)
    url = URI.parse('https://cas.chula.ac.th/cas/api/?q=studentAuthenticate')
    appid = '41508763e340d5858c00f8c1a0f5a2bb'
    appsecret ='d9cbb5863091dbe186fded85722a1e31'
    post_args = {
      'appid' => appid,
      'appsecret' => appsecret,
      'username' => login,
      'password' => password
    }

    #simple call
    begin
      http = Net::HTTP.new('cas.chula.ac.th', 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      result = [ ]
      http.start do |http|
        req = Net::HTTP::Post.new('/cas/api/?q=studentAuthenticate')
        #req = Net::HTTP::Post.new('/appX/prod/?q=studentAuthenticate')
        #req = Net::HTTP::Post.new('/app2/prod/api/?q=studentAuthenticate')
        param = "appid=#{appid}&appsecret=#{appsecret}&username=#{login}&password=#{password}"
        resp = http.request(req,param)
        result = JSON.parse resp.body
        puts result
      end
      return true if result["type"] == "beanStudent"
    rescue => e
      puts e
      puts e.message
      return false
    end
    return false
  end


  def authenticated?(password)
    if self.activated
      hashed_password == User.encrypt(password,self.salt)
    else
      false
    end
  end

  def login_with_name
    "[#{login}] #{full_name}"
  end

  def admin?
    @is_admin = has_role?('admin') if @is_admin.nil?
    return @is_admin
  end

  def has_role?(role)
    self.roles.where(name: [role,'admin']).count > 0
  end

  def email_for_editing
    if self.email==nil
      "(unknown)"
    elsif self.email==''
      "(blank)"
    else
      self.email
    end
  end

  def email_for_editing=(e)
    self.email=e
  end

  def alias_for_editing
    if self.alias==nil
      "(unknown)"
    elsif self.alias==''
      "(blank)"
    else
      self.alias
    end
  end

  def alias_for_editing=(e)
    self.alias=e
  end

  def activation_key
    if self.hashed_password==nil
      encrypt_new_password
    end
    Digest::SHA1.hexdigest(self.hashed_password)[0..7]
  end

  def verify_activation_key(key)
    key == activation_key
  end

  def self.random_password(length=5)
    chars = 'abcdefghjkmnopqrstuvwxyz'
    password = ''
    length.times { password << chars[rand(chars.length - 1)] }
    password
  end


  # Contest information

  def self.find_users_with_no_contest()
    users = User.all
    return users.find_all { |u| u.contests.length == 0 }
  end


  def contest_time_left
    if GraderConfiguration.contest_mode?
      return nil if site==nil
      return site.time_left
    elsif GraderConfiguration.indv_contest_mode?
      time_limit = GraderConfiguration.contest_time_limit
      if time_limit == nil
        return nil
      end
      if contest_stat==nil or contest_stat.started_at==nil
        return (Time.now.gmtime + time_limit) - Time.now.gmtime
      else
        finish_time = contest_stat.started_at + time_limit
        current_time = Time.now.gmtime
        if current_time > finish_time
          return 0
        else
          return finish_time - current_time
        end
      end
    else
      return nil
    end
  end

  def contest_finished?
    if GraderConfiguration.contest_mode?
      return false if site==nil
      return site.finished?
    elsif GraderConfiguration.indv_contest_mode?
      return false if self.contest_stat==nil
      return contest_time_left == 0
    else
      return false
    end
  end

  def contest_started?
    if GraderConfiguration.indv_contest_mode?
      stat = self.contest_stat
      return ((stat != nil) and (stat.started_at != nil))
    elsif GraderConfiguration.contest_mode?
      return true if site==nil
      return site.started
    else
      return true
    end
  end

  def update_start_time
    stat = self.contest_stat
    if stat.nil? or stat.started_at.nil?
      stat ||= UserContestStat.new(:user => self)
      stat.started_at = Time.now.gmtime
      stat.save
    end
  end

  def problem_in_user_contests?(problem)
    problem_contests = problem.contests.all

    if problem_contests.length == 0   # this is public contest
      return true
    end

    contests.each do |contest|
      if problem_contests.find {|c| c.id == contest.id }
        return true
      end
    end
    return false
  end

  def available_problems_group_by_contests
    contest_problems = []
    pin = {}
    contests.enabled.each do |contest|
      available_problems = contest.problems.available
      contest_problems << {
        :contest => contest,
        :problems => available_problems
      }
      available_problems.each {|p| pin[p.id] = true}
    end
    other_avaiable_problems = Problem.available.find_all {|p| pin[p.id]==nil and p.contests.length==0}
    contest_problems << {
      :contest => nil,
      :problems => other_avaiable_problems
    }
    return contest_problems
  end

  def solve_all_available_problems?
    available_problems.each do |p|
      u = self
      sub = Submission.find_last_by_user_and_problem(u.id,p.id)
      return false if !p || !sub || sub.points < 100
    end
    return true
  end

  #get a list of available problem
  def available_problems
    # first, we check if this is normal mode
    unless GraderConfiguration.multicontests?

      #if this is a normal mode
      #we show problem based on problem_group, if the config said so
      if GraderConfiguration.use_problem_group?
        return available_problems_in_group
      else
        return Problem.available_problems
      end
    else
      #this is multi contest mode
      contest_problems = []
      pin = {}
      contests.enabled.each do |contest|
        contest.problems.available.each do |problem|
          if not pin.has_key? problem.id
            contest_problems << problem
          end
          pin[problem.id] = true
        end
      end
      other_avaiable_problems = Problem.available.find_all {|p| pin[p.id]==nil and p.contests.length==0}
      return contest_problems + other_avaiable_problems
    end
  end

  # new feature, get list of available problem in all enabled group that the user belongs to
  def available_problems_in_group
    pids = self.groups.where(enabled: true).joins(:problems).select('distinct problem_id').pluck :problem_id
    return Problem.where(id: pids).where(available: true).order('date_added DESC').order('name')
  end

  #check if the user has the right to view that problem
  #this also consider group based problem policy
  def can_view_problem?(problem)
    return true if admin?
    return available_problems.include? problem
  end

  def self.clear_last_login
    User.update_all(last_ip: nil)
  end

  def get_jschart_user_sub_history
    start = 4.month.ago.beginning_of_day
    start_date = start.to_date
    count = Submission.where(user: self).where('submitted_at >= ?', start).group('DATE(submitted_at)').count
    i = 0
    label = []
    value = []
    while (start_date + i < Time.zone.now.to_date)
      label << (start_date+i).strftime("%d-%b")
      value << (count[start_date+i] || 0)
      i+=1
    end
    return {labels: label,datasets: [label:'sub',data: value, backgroundColor: 'rgba(54, 162, 235, 0.2)', borderColor: 'rgb(75, 192, 192)']}
  end

  #create multiple user, one per lines of input
  def self.create_from_list(lines)
    error_logins = []
    first_error = nil
    created_users = []

    lines.split("\n").each do |line|
      #split with large limit, this will cause consecutive ',' to be result in a blank
      items = line.chomp.split(',',1000)
      if items.length>=2
        login = items[0]
        full_name = items[1]
        remark =''
        user_alias = ''

        added_random_password = false
        added_password = false

        #given password?
        if items.length >= 3
          if items[2].chomp(" ").length > 0
            password = items[2].chomp(" ")
            added_password = true
          end
        else
          password = random_password
          added_random_password=true;
        end

        #given alias?
        if items.length>= 4 and items[3].chomp(" ").length > 0;
          user_alias = items[3].chomp(" ")
        else
          user_alias = login
        end

        #given remark?
        has_remark = false
        if items.length>=5
          remark = items[4].strip;
          has_remark = true
        end

        user = User.find_by_login(login)
        if (user)
          user.full_name = full_name
          user.remark = remark if has_remark
          user.password = password if added_password || added_random_password
        else
          #create a random password if none are given
          password = random_password unless password
          user = User.new({:login => login,
                           :full_name => full_name,
                           :password => password,
                           :password_confirmation => password,
                           :alias => user_alias,
                           :remark => remark})
        end
        user.activated = true

        if user.save
          created_users << user
        else
          error_logins << "'#{login}'"
          first_error = user.errors.full_messages.to_sentence unless first_error
        end
      end
    end

    return {error_logins: error_logins, first_error: first_error, created_users: created_users}

  end

  def self.find_non_admin_with_prefix(prefix='')
    users = User.all
    return users.find_all { |u| !(u.admin?) and u.login.index(prefix)==0 }
  end

  protected
    def encrypt_new_password
      return if password.blank?
      self.salt = (10+rand(90)).to_s
      self.hashed_password = User.encrypt(self.password,self.salt)
    end

    def assign_default_site
      # have to catch error when migrating (because self.site is not available).
      begin
        if self.site==nil
          self.site = Site.find_by_name('default')
          if self.site==nil
            self.site = Site.find(1)  # when 'default has be renamed'
          end
        end
      rescue
      end
    end

    def assign_default_contest
      # have to catch error when migrating (because self.site is not available).
      begin
        if self.contests.length == 0
          default_contest = Contest.find_by_name(GraderConfiguration['contest.default_contest_name'])
          if default_contest
            self.contests = [default_contest]
          end
        end
      rescue
      end
    end

    def password_required?
      self.hashed_password.blank? || !self.password.blank?
    end
  
    def self.encrypt(string,salt)
      Digest::SHA1.hexdigest(salt + string)
    end

    def uniqueness_of_email_from_activated_users
      user = User.activated_users.find_by_email(self.email)
      if user and (user.login != self.login)
        self.errors.add(:base,"Email has already been taken")
      end
    end
    
    def enough_time_interval_between_same_email_registrations
      return if !self.new_record?
      return if self.activated
      open_user = User.find_by_email(self.email,
                                     :order => 'created_at DESC')
      if open_user and open_user.created_at and 
          (open_user.created_at > Time.now.gmtime - 5.minutes)
        self.errors.add(:base,"There are already unactivated registrations with this e-mail address (please wait for 5 minutes)")
      end
    end

    def email_validation?
      begin
        return VALIDATE_USER_EMAILS
      rescue
        return false
      end
    end
end
