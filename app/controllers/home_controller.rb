class HomeController < ApplicationController
  def index
    # ELO statistics
    @top_elo_players = Player.joins(:team_players)
      .where.not(elo_rating: nil)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('players.id', 'players.igname')
      .order('players.elo_rating DESC')
      .first(3)
  end
end
