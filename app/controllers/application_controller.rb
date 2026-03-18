class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  private

  def after_sign_in_path_for(player)
    request.env["omniauth.origin"] || stored_location_for(player) || root_path
  end

  def pundit_user
    current_player
  end
end
