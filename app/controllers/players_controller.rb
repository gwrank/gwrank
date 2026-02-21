class PlayersController < ApplicationController
  def index
    @pagy, @players = pagy(Player.with_igname.order(updated_at: :desc, created_at: :desc))
  end

  def show
    @player = Player.friendly.find(params[:id])
  end
end
