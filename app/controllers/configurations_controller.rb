class ConfigurationsController < ApplicationController

  before_action :admin_authorization
  before_action :set_config, only: [:update, :toggle, :edit]

  def index
    @configurations = GraderConfiguration.order(:key)
    @group = GraderConfiguration.pluck("grader_configurations.key").map{ |x| x[0...(x.index('.'))] }.uniq.sort
  end

  def edit
  end

  def reload
    GraderConfiguration.reload
    redirect_to :action => 'index'
  end

  def clear_user_ip
    User.clear_last_login
  end

  def update
    respond_to do |format|
      if @config.update(configuration_params)
        format.json { head :ok }
        format.turbo_stream
      end
    end
  end

  def toggle
    if @config.value == "true"
      @config.update(value: "false")
    else
      @config.update(value: "true")
    end

    # hook
    if @config.key == GraderConfiguration::SINGLE_USER_KEY && @config.value == 'true'
      GraderConfiguration.update_min_last_login
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  def set_exam_right
    value = params[:value] || 'false'
    GraderConfiguration.where(key: "right.bypass_agreement").update(value: value);
    GraderConfiguration.where(key: "right.multiple_ip_login").update(value: value);
    GraderConfiguration.where(key: "right.user_hall_of_fame").update(value: value);
    GraderConfiguration.where(key: "right.user_view_submission ").update(value: value);
    GraderConfiguration.where(key: "right.view_testcase ").update(value: value);
    redirect_to :action => 'index'
  end

private
  def configuration_params
    params.require(:grader_configuration).permit(:key,:value_type,:value,:description)
  end

  def set_config
    @config = GraderConfiguration.find(params[:id])
  end

end
