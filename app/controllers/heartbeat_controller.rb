class HeartbeatController < ApplicationController
  before_action :admin_authorization, :only => ['index']

  def edit
    #@user = User.find_by_login(params[:id])
    #unless @user
    #  render text: "LOGIN_NOT_FOUND"
    #  return
    #end

    #hb = HeartBeat.where(user_id: @user.id, ip_address: request.remote_ip).first
    #puts "status = #{params[:status]}"
    #if hb
    #  if params[:status]
    #    hb.status = params[:status]
    #    hb.save
    #  end
    #  hb.touch
    #else
    #  HeartBeat.creae(user_id: @user.id, ip_address: request.remote_ip)
    #end
    #HeartBeat.create(user_id: @user.id, ip_address: request.remote_ip, status: params[:status])

    res = GraderConfiguration['right.heartbeat_response']
    res.strip! if res
    full = GraderConfiguration['right.heartbeat_response_full']
    full.strip! if full

    if full and full != ''
      l = Login.where(ip_address: request.remote_ip).last
      @user = l.user
      if @user.solve_all_available_problems?
        render text: (full || 'OK')
      else
        render text: (res || 'OK')
      end
    else
      render text: (GraderConfiguration['right.heartbeat_response'] || 'OK')
    end
  end

  def index
    @hb = HeartBeat.where("updated_at >= ?",Time.zone.now-2.hours).includes(:user).order(:user_id).all
    @num = HeartBeat.where("updated_at >= ?",Time.zone.now-5.minutes).count(:user_id,distinct: true)
  end
end
