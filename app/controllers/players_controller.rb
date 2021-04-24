class PlayersController < ApplicationController
  before_action :authenticate_player!

  def index
    @players = Player.with_igname.order(igname: :asc)
  end

  def show
    @player = Player.friendly.find(params[:id])
  end
end
