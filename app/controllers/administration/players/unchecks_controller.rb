module Administration
  class Players::UnchecksController < ApplicationController
    def create
      @player = Player.find(params[:player_id])
      @player.update(is_verified: false)
      redirect_to administration_players_path
    end
  end
end
