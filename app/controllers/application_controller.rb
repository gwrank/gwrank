class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  layout :determine_gw_layout

  private

  def determine_gw_layout
    devise_controller? ? "gw" : nil
  end

  def after_sign_in_path_for(player)
    request.env["omniauth.origin"] || stored_location_for(player) || root_path
  end

  def pundit_user
    current_player
  end
end
