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
    redirect_to root_path
  end
end
