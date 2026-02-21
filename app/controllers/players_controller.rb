class PlayersController < ApplicationController
  def index
    @pagy, @players = pagy(Player.with_igname.order(igname: :asc))
  end

  def show
    @player = Player.friendly.find(params[:id])
  end
end
