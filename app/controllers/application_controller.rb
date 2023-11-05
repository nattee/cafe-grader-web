require 'ipaddr'
require "securerandom"

class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :read_grader_configuration
  before_action :current_user
  before_action :header_info
  before_action :unique_visitor_id
  before_action :active_controller_action

  SINGLE_USER_MODE_CONF_KEY = 'system.single_user_mode'
  MULTIPLE_IP_LOGIN_CONF_KEY = 'right.multiple_ip_login'
  WHITELIST_IGNORE_CONF_KEY = 'right.whitelist_ignore'
  WHITELIST_IP_CONF_KEY = 'right.whitelist_ip'

  # report and redirect for unauthorized activities
  def unauthorized_redirect(msg = 'You are not authorized to view the page you requested')
    session[:user_id] = nil
    if @current_user && false == GraderConfiguration[SINGLE_USER_MODE_CONF_KEY]
      redirect_to list_main_path, alert: msg
    else
      redirect_to login_main_path, alert: msg
    end
  end

  # Returns the current logged-in user (if any).
  def current_user
    return nil unless session[:user_id]
    @current_user ||= User.find(session[:user_id])
  end

  def read_grader_configuration
    #read all config into a hash and store at BOTH @grader_config of the controller and the class variable of GraderConfiguration
    if @grader_configuration.nil?
      @grader_configuration = GraderConfiguration.read_config
    end
  end

  def header_info
    @nav_announcement = Announcement.where(on_nav_bar: true)
    if @current_user && @current_user.admin?
      #if not admin, this info is not needed
      @backlog = Submission.where('graded_at is null').where('submitted_at < ?', 1.minutes.ago).count
    end
  end

  def active_controller_action
    #so that we can override this value inside each action
    @active_controller = controller_name
    @active_action = action_name
  end

  def admin_authorization
    return false unless check_valid_login
    user = User.includes(:roles).find(session[:user_id])
    unless user.admin?
      unauthorized_redirect
      return false
    end
    return true
  end

  def authorization_by_roles(allowed_roles)
    return false unless check_valid_login
    return true if @current_user.admin?
    roles.each do |r|
      return true if @current_user.has_role?(r)
    end
    unauthorized_redirect
  end


  def unique_visitor_id
    unless cookies.encrypted[:uuid]
      value = SecureRandom.uuid
      cookies.encrypted[:uuid] = { value: value, expires: 20.year }
    end
    return cookies.encrypted[:uuid]
  end

  protected

  #redirect to root (and also force logout)
  #if the user is not logged_in or the system is in "ADMIN ONLY" mode

  def check_valid_login


    #check if logged in
    unless @current_user
      if GraderConfiguration[SINGLE_USER_MODE_CONF_KEY]
        unauthorized_redirect('You need to login but you cannot log in at this time')
      else
        unauthorized_redirect('You need to login')
      end
      return false
    end

    #check expired session for non-admin
    if !@current_user.admin?
      unless session[:last_login] &&
          Time.new(session[:last_login]) >= GraderConfiguration.minimum_last_login_time
        unauthorized_redirect('Your session is expired, please login again.')
        return
      end
    end

    # check if run in single user mode
    if GraderConfiguration[SINGLE_USER_MODE_CONF_KEY] && !@current_user.admin?
      unauthorized_redirect('You cannot log in at this time')
      return false
    end

    # check if the user is enabled
    unless @current_user.enabled? || @current_user.admin?
      unauthorized_redirect 'Your account is disabled'
      return false
    end

    # check if user ip is allowed
    unless @current_user.admin? || GraderConfiguration[WHITELIST_IGNORE_CONF_KEY]
      unless is_request_ip_allowed?
        unauthorized_redirect 'Your IP is not allowed to login at this time.'
        return false
      end
    end

    # check unique visitor id
    unless @current_user.admin? || GraderConfiguration[MULTIPLE_IP_LOGIN_CONF_KEY]
      visitor_id = unique_visitor_id
      if @current_user.last_ip && @current_user.last_ip != visitor_id
        redirect_to login_main_path, alert: "You cannot login from two different places"
        return false
      end
      unless user.last_ip
        @current_user.last_ip = visitor_id
        @current_user.save
      end
    end

    # check multi contest
    if GraderConfiguration.multicontests?
      return true if @current_user.admin?
      begin
        if @current_user.contest_stat(true).forced_logout
          flash[:notice] = 'You have been automatically logged out.'
          redirect_to :controller => 'main', :action => 'index'
        end
      rescue
      end
    end
    return true
  end

  def authorization
    return false unless check_valid_login
    user = User.find(session[:user_id])
    unless user.roles.detect { |role|
        role.rights.detect{ |right|
          right.controller == self.class.controller_name and
            (right.action == 'all' || right.action == action_name)
        }
      }
      flash[:notice] = 'You are not authorized to view the page you requested'
      #request.env['HTTP_REFERER'] ? (redirect_to :back) : (redirect_to :controller => 'login')
      redirect_to :controller => 'main', :action => 'login'
      return false
    end
  end

  def verify_time_limit
    return true if session[:user_id]==nil
    user = User.find(session[:user_id], :include => :site)
    return true if user==nil || user.site == nil
    if user.contest_finished?
      flash[:notice] = 'Error: the contest you are participating is over.'
      redirect_to :back
      return false
    end
    return true
  end

  def is_request_ip_allowed?
    unless GraderConfiguration[WHITELIST_IGNORE_CONF_KEY]
      user_ip = IPAddr.new(request.remote_ip)
      allowed = GraderConfiguration[WHITELIST_IP_CONF_KEY] || ''

      allowed.delete(' ').split(',').each do |ips|
        allow_ips = IPAddr.new(ips)
        if allow_ips.include?(user_ip)
          return true
        end
      end
      return false
    end
    return true
  end

  #function for datatable ajax query
  #return record,total_count,filter_count
  def process_query_record(record, 
                           total_count: nil,
                           select: '',
                           global_search: [],
                           no_search: false,
                           force_order: '',
                           date_filter: '', date_param_since: 'date_since',date_param_until: 'date_until',
                           hard_limit: nil)
    arel_table = record.model.arel_table

    if !no_search && params['search']
      global_value = record.model.sanitize_sql(params['search']['value'].strip.downcase)
      if !global_value.blank?
        global_value.split.each do |value|
          global_where = global_search.map{|f| "LOWER(#{f}) like '%#{value}%'"}.join(' OR ')
          record = record.where(global_where)
        end
      end

      params['columns'].each do |i, col|
        if !col['search']['value'].blank?
          record = record.where(arel_table[col['name']].lower.matches("%#{col['search']['value'].strip.downcase}%"))
        end
      end
    end

    if !date_filter.blank?
      param_since = params[date_param_since]
      param_until = params[date_param_until]
      date_since = Time.zone.parse( param_since ) || Time.new(1,1,1) rescue Time.new(1,1,1)
      date_until = Time.zone.parse( param_until ) || Time.zone.now() rescue Time.zone.now()
      date_range = date_since..(date_until.end_of_day)
      record = record.where(date_filter.to_sym => date_range)
    end

    if force_order.blank?
      if params['order']
        params['order'].each do |i, o|
          colName = params['columns'][o['column']]['name']
          colName = "#{record.model.table_name}.#{colName}" if colName.upcase == 'ID'
          record = record.order("#{colName} #{o['dir'].casecmp('desc') != 0 ? 'ASC' : 'DESC'}") unless colName.blank?
        end
      end
    else
      record = record.order(force_order)
    end

    filterCount = record.count(record.model.primary_key)
    # if .group() is used, filterCount might be like {id_1: count_1, id_2: count_2, ...}
    # so we should count the result again..
    if filterCount.is_a? Hash
      filterCount = filterCount.count
    end


    record = record.offset(params['start'] || 0)
    record = record.limit(hard_limit)
    if (params['length'])
      limit = params['length'].to_i
      limit == hard_limit if (hard_limit && hard_limit < limit)
      record = record.limit(limit)
    end
    if (!select.blank?)
      record = record.select(select)
    end

    return record, total_count || record.model.count, filterCount
  end

  #parse the string given from tempus dominus, set default when error
  def parse_td_datetime(text, default = Time.zone.now)
    md = text.match(/(\d+)\/(\d+)\/(\d+), (\d+):(\d+)/)
    result = Time.zone.local(md[3].to_i,md[2].to_i,md[1].to_i,md[4].to_i,md[5].to_i) rescue default
    return result
  end
  

end
