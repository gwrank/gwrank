class PlayersController < ApplicationController
  def index
    @players = Player.all.order(created_at: :desc)
  end

  def show
    @player = Player.friendly.find(params[:id])
  end
end
