require 'net/smtp'

class UsersController < ApplicationController

  include MailHelperMethods

  before_action :check_valid_login, :except => [:new,
                                           :register,
                                           :confirm,
                                           :forget,
                                           :retrieve_password]

  before_action :verify_online_registration, :only => [:new,
                                                       :register,
                                                       :forget,
                                                       :retrieve_password]

  before_action :admin_authorization, only: [:stat, :toggle_activate, :toggle_enable]

  def index
    if !GraderConfiguration['system.user_setting_enabled']
      redirect_to :controller => 'main', :action => 'list'
    else
      @user = User.find(session[:user_id])
    end
  end

  # edit logged in user profile
  def profile
    if !GraderConfiguration['system.user_setting_enabled']
      redirect_to :controller => 'main', :action => 'list'
    else
      @user = current_user;
    end
  end

  def chg_passwd
    user = User.find(session[:user_id])
    user.password = params[:password]
    user.password_confirmation = params[:password_confirmation]
    if user.save
      flash[:notice] = 'password changed'
    else
      flash[:notice] = 'Error: password changing failed'
    end
    redirect_to :action => 'profile'
  end

  def chg_default_language
    user = User.find(session[:user_id])
    user.default_language_id = params[:default_language]
    if user.save
      flash[:notice] = 'default language changed'
    else
      flash[:notice] = 'Error: default language changing failed'
    end
    redirect_to :action => 'profile'
  end

  def update_self
    user = @current_user
    if user.update(user_update_params)
      redirect_to profile_users_path, notice: 'Updated successfully'
    else
      render :profile
    end
  end

  def new
    @user = User.new
    render :action => 'new', :layout => 'empty'
  end

  def register
    if(params[:cancel])
      redirect_to :controller => 'main', :action => 'login'
      return
    end
    @user = User.new(user_params)
    @user.password_confirmation = @user.password = User.random_password
    @user.activated = false
    if (@user.valid?) and (@user.save)
      if send_confirmation_email(@user)
        render :action => 'new_splash', :layout => 'empty'
      else
        @admin_email = GraderConfiguration['system.admin_email']
        render :action => 'email_error', :layout => 'empty'
      end
    else
      @user.errors.add(:base,"Email cannot be blank") if @user.email==''
      render :action => 'new', :layout => 'empty'
    end
  end

  def confirm
    login = params[:login]
    key = params[:activation]
    @user = User.find_by_login(login)
    if (@user) and (@user.verify_activation_key(key))
      if @user.valid?  # check uniquenss of email
        @user.activated = true
        @user.save
        @result = :successful
      else
        @result = :email_used
      end
    else
      @result = :failed
    end
    render :action => 'confirm', :layout => 'empty'
  end

  def forget
    render :action => 'forget', :layout => 'empty'
  end

  def retrieve_password
    email = params[:email]
    user = User.find_by_email(email)
    if user
      last_updated_time = user.updated_at || user.created_at || (Time.now.gmtime - 1.hour)
      if last_updated_time > Time.now.gmtime - 5.minutes
        flash[:notice] = 'The account has recently created or new password has recently been requested.  Please wait for 5 minutes'
      else
        user.password = user.password_confirmation = User.random_password
        user.save
        send_new_password_email(user)
        flash[:notice] = 'New password has been mailed to you.'
      end
    else
      flash[:notice] = I18n.t 'registration.password_retrieval.no_email'
    end
    redirect_to :action => 'forget'
  end

  protected

  def verify_online_registration
    if !GraderConfiguration['system.online_registration']
      redirect_to :controller => 'main', :action => 'login'
    end
  end

  def send_confirmation_email(user)
    contest_name = GraderConfiguration['contest.name']
    activation_url = url_for(:action => 'confirm', 
                             :login => user.login, 
                             :activation => user.activation_key)
    home_url = url_for(:controller => 'main', :action => 'index')
    mail_subject = "[#{contest_name}] Confirmation"
    mail_body = t('registration.email_body', {
                    :full_name => user.full_name,
                    :contest_name => contest_name,
                    :login => user.login,
                    :password => user.password,
                    :activation_url => activation_url,
                    :admin_email => GraderConfiguration['system.admin_email']
                  })

    logger.info mail_body

    send_mail(user.email, mail_subject, mail_body)
  end
  
  def send_new_password_email(user)
    contest_name = GraderConfiguration['contest.name']
    mail_subject = "[#{contest_name}] Password recovery"
    mail_body = t('registration.password_retrieval.email_body', {
                    :full_name => user.full_name,
                    :contest_name => contest_name,
                    :login => user.login,
                    :password => user.password,
                    :admin_email => GraderConfiguration['system.admin_email']
                  })

    logger.info mail_body

    send_mail(user.email, mail_subject, mail_body)
  end

  # allow viewing of regular user profile only when options allow so
  # only admins can view admins profile
  def profile_authorization
    #if view admins' profile, allow only admin
    return false unless(params[:id])
    user = User.find(params[:id])
    return false unless user
    return admin_authorization if user.admin?
    return true if GraderConfiguration["right.user_view_submission"]

    #finally, we allow only admin
    admin_authorization
  end

  private
    def user_params
      params.require(:user).permit(:login, :full_name, :email)
    end

    def user_update_params
      params.require(:user).permit(:default_language_id, :password, :password_confirmation)
    end
end
