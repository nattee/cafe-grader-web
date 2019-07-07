require 'ipaddr'

class ApplicationController < ActionController::Base
  protect_from_forgery

  before_action :current_user

  SINGLE_USER_MODE_CONF_KEY = 'system.single_user_mode'
  MULTIPLE_IP_LOGIN_CONF_KEY = 'right.multiple_ip_login'
  ALLOW_WHITELIST_IP_ONLY_CONF_KEY = 'right.allow_whitelist_ip_only'
  WHITELIST_IP_CONF_KEY = 'right.whitelist_ip'

  #report and redirect for unauthorized activities
  def unauthorized_redirect
    flash[:notice] = 'You are not authorized to view the page you requested'
    redirect_to :controller => 'main', :action => 'login'
  end

  # Returns the current logged-in user (if any).
  def current_user
    return nil unless session[:user_id]
    @current_user ||= User.find(session[:user_id])
  end

  def admin_authorization
    return false unless authenticate
    user = User.includes(:roles).find(session[:user_id])
    unless user.admin?
      unauthorized_redirect
      return false
    end
    return true
  end

  def authorization_by_roles(allowed_roles)
    return false unless authenticate
    user = User.find(session[:user_id])
    unless user.roles.detect { |role| allowed_roles.member?(role.name) }
      unauthorized_redirect
      return false
    end
  end

  def testcase_authorization
    #admin always has privileged
    if @current_user.admin?
      return true
    end

    unauthorized_redirect unless GraderConfiguration["right.view_testcase"]
  end


  protected

  #redirect to root (and also force logout)
  #if the user is not logged_in or the system is in "ADMIN ONLY" mode
  def authenticate
    unless session[:user_id]
      flash[:notice] = 'You need to login'
      if GraderConfiguration[SINGLE_USER_MODE_CONF_KEY]
        flash[:notice] = 'You need to login but you cannot log in at this time'
      end
      redirect_to :controller => 'main', :action => 'login'
      return false
    end

    # check if run in single user mode
    if GraderConfiguration[SINGLE_USER_MODE_CONF_KEY]
      if @current_user==nil || (not @current_user.admin?)
        flash[:notice] = 'You cannot log in at this time'
        redirect_to :controller => 'main', :action => 'login'
        return false
      end
    end

    # check if the user is enabled
    unless @current_user.enabled? || @current_user.admin?
      flash[:notice] = 'Your account is disabled'
      redirect_to :controller => 'main', :action => 'login'
      return false
    end

    # check if user ip is allowed
    unless @current_user.admin? || !GraderConfiguration[ALLOW_WHITELIST_IP_ONLY_CONF_KEY]
      unless is_request_ip_allowed?
        flash[:notice] = 'Your IP is not allowed'
        redirect_to root_path
      end
    end

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

  #redirect to root (and also force logout)
  #if the user use different ip from the previous connection
  #  only applicable when MULTIPLE_IP_LOGIN options is false only
  def authenticate_by_ip_address
    #this assume that we have already authenticate normally
    unless GraderConfiguration[MULTIPLE_IP_LOGIN_CONF_KEY]
      user = User.find(session[:user_id])
      if (not @current_user.admin? && user.last_ip && user.last_ip != request.remote_ip)
        flash[:notice] = "You cannot use the system from #{request.remote_ip}. Your last ip is #{user.last_ip}"
        redirect_to :controller => 'main', :action => 'login'
        puts "CHEAT: user #{user.login} tried to login from '#{request.remote_ip}' while last ip is '#{user.last_ip}' at #{Time.zone.now}"
        return false
      end
      unless user.last_ip
        user.last_ip = request.remote_ip
        user.save
      end
    end
    return true
  end

  def authorization
    return false unless authenticate
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
    if GraderConfiguration[ALLOW_WHITELIST_IP_ONLY_CONF_KEY]
      user_ip = IPAddr.new(request.remote_ip)
      GraderConfiguration[WHITELIST_IP_LIST_CONF_KEY].delete(' ').split(',').each do |ips|
        allow_ips = IPAddr.new(ips)
        unless allow_ips.includes(user_ip)
          return false
        end
      end
    end
    return true
  end

end
