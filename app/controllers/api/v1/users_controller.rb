class Api::V1::UsersController < Api::V1::BaseController
  def me
    render json: {
      id: current_user.id,
      login: current_user.login,
      full_name: current_user.full_name,
      alias: current_user.alias,
      email: current_user.email,
      section: current_user.section,
      remark: current_user.remark,
      admin: current_user.admin?
    }
  end
end
