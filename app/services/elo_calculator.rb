class EloCalculator
  K_FACTOR = 32
  DEFAULT_ELO = 1200

  def initialize(winner_team:, loser_team:)
    @winner_team = winner_team
    @loser_team = loser_team
  end

  def call!
    winner_avg = average_elo(@winner_team)
    loser_avg = average_elo(@loser_team)

    update_players!(@winner_team, opponent_avg: loser_avg, result: 1, stat_key: 'opponent_elo_at_match')
    update_players!(@loser_team, opponent_avg: winner_avg, result: 0, stat_key: 'team_elo_at_match')
  end

  private

  def average_elo(team)
    rated_players = team.players.where.not(elo_rating: nil)
    return DEFAULT_ELO if rated_players.count.zero?

    rated_players.sum(:elo_rating) / rated_players.count
  end

  def update_players!(team, opponent_avg:, result:, stat_key:)
    team.team_players.each do |team_player|
      player = team_player.player
      next unless player

      player_elo = player.elo_rating || DEFAULT_ELO
      player_elo_matches = player.elo_matches || 0
      expected_score = 1 / (1 + 10**((opponent_avg - player_elo) / 400.0))
      new_elo = (player_elo + K_FACTOR * (result - expected_score)).round

      team_player.team_player_stats.where(stat_key: stat_key).first_or_create!(stat_value: opponent_avg)
      player.update!(elo_rating: new_elo, elo_matches: player_elo_matches + 1)
    end
  end
end
