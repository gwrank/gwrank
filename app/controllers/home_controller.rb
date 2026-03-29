class HomeController < ApplicationController
  def index
    # ELO statistics
    @top_elo_players = Player.joins(:team_players)
      .where.not(elo_rating: nil)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('players.id', 'players.igname')
      .order('players.elo_rating DESC')
      .first(3)
      
    # Get the latest mAT final match for homepage display
    @last_match = Match.includes(teams: [:guild, { team_players: [:profession, :secondary_profession, { team_player_skills: :skill }] }])
                      .joins(:tournament)
                      .where(tournaments: { tournament_type: 'mat' })
                      .where(round: 4)
                      .order(played_at: :desc)
                      .first
    
    # Get unique maps for the filter dropdown (same as matches controller)
    @unique_maps = Match.unique_maps
  end
end
