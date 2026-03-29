class HomeController < ApplicationController
  def index
    # Get the latest mAT final match for homepage display
    @last_match = Rails.cache.fetch("last_mat_final_match", expires_in: 1.day) do
      Match.includes(teams: [:guild, { team_players: [:profession, :secondary_profession, { team_player_skills: :skill }] }])
            .joins(:tournament)
            .where(tournaments: { tournament_type: 'mat' })
            .where(round: 4)
            .order(played_at: :desc)
            .first
    end
    
    # Get unique maps for the filter dropdown (same as matches controller)
    @unique_maps = Rails.cache.fetch("unique_maps", expires_in: 1.day) do
      Match.unique_maps
    end
  end
end
