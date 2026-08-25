class Players::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def discord
    @player = Player.from_omniauth(request.env["omniauth.auth"])

    if @player.persisted?
      sign_in_and_redirect @player, event: :authentication
      set_flash_message(:notice, :success, kind: "Discord") if is_navigational_format?
    else
      session["devise.discord_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_player_registration_url, alert: request.env["omniauth.auth"]
    end
  end

  def failure
    Rails.logger.warn(
      "[OMNIAUTH-DEBUG] type=#{request.env["omniauth.error.type"].inspect} " \
      "error=#{request.env["omniauth.error"].inspect} " \
      "strategy=#{request.env["omniauth.error.strategy"]&.name.inspect} " \
      "host=#{request.host} session_state=#{session[:omniauth.state].inspect} " \
      "param_state=#{params[:state].inspect}"
    )
    redirect_to root_path
  end
end
