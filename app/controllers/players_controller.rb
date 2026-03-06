class PlayersController < ApplicationController
  def index
    @pagy, @players = pagy(
      Player.with_igname
        .order("elo_rating IS NULL", "elo_matches IS NULL", elo_rating: :desc, elo_matches: :desc),
      limit: 18
    )
  end

  def show
    @player = Player.friendly.find(params[:id])
  end
end
