class PlayersController < ApplicationController
  def show
    @player = Player.friendly.find(params[:id])
  end
end
