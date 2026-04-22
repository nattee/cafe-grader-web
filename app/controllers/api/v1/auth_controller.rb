class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_api_user!, only: [:login]

  def login
    user = User.authenticate(params[:login], params[:password])
    unless user
      render json: { error: "Invalid login or password" }, status: :unauthorized and return
    end

    token = JWT.encode(
      { user_id: user.id, exp: 7.days.from_now.to_i, iat: Time.now.to_i },
      jwt_secret,
      "HS256"
    )

    render json: {
      token: token,
      user: {
        id: user.id,
        login: user.login,
        full_name: user.full_name
      }
    }
  end
end
