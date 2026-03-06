class PlayersController < ApplicationController
  def index
    @pagy, @players = pagy(
      Player.with_igname
        .where('elo_rating IS NOT NULL')
        .order(elo_rating: :desc, elo_matches: :desc),
      limit: 18
    )
  end

  def show
    @player = Player.friendly.find(params[:id])
  end
end
