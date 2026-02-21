class ApiTokensController < ApplicationController
  before_action :authenticate_player!

  def show
    current_player.regenerate_api_token unless current_player.api_token.present?
  end
end
