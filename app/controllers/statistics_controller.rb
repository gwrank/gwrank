class StatisticsController < ApplicationController
  def index
    # ELO statistics - top 10 players by ELO rating
    @top_elo_players = Player.joins(:team_players)
      .where.not(elo_rating: nil)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('players.id', 'players.igname')
      # FIXME: .having('COUNT(team_players.id) >= 5')
      .order('players.elo_rating DESC')
      .first(10)

    # Most improved players (players with biggest ELO increase recently)
    @most_improved_players = calculate_most_improved_players

    # ELO distribution by profession
    @elo_by_profession = calculate_elo_by_profession

    # Top 10 players by ELO for each profession
    @top_players_by_profession = calculate_top_players_by_profession
  end

  private

  def calculate_most_improved_players
    # Players who have the highest average ELO gain per match
    # This requires tracking ELO changes over time
    # For now, we'll show players with high ELO who have many matches
    Player.joins(:team_players)
      .where.not(elo_rating: nil)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('players.id', 'players.igname')
      # FIXME: .having('COUNT(team_players.id) >= 10')
      .order('players.elo_rating DESC, players.updated_at DESC')
      .first(5)
  end

  def calculate_elo_by_profession
    # Calculate average ELO by profession for top players
    profession_stats = {}
    Player.joins(:team_players)
      .where.not(elo_rating: nil)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .where('players.elo_rating IS NOT NULL')
      .group('team_players.profession_id')
      # FIXME: .having('COUNT(team_players.id) >= 5')
      .order('avg_elo DESC')
      .select('team_players.profession_id, AVG(players.elo_rating) as avg_elo, COUNT(team_players.id) as match_count')
      .each do |record|
        profession = Profession.find(record.profession_id)
        profession_stats[profession.name] = {
          avg_elo: record.avg_elo.round(2),
          player_count: record.match_count.to_i
        }
      end
    profession_stats
  end

  def calculate_top_players_by_profession
    # Get top 10 players by ELO for each profession
    profession_stats = {}
    Profession.all.each do |profession|
      players = Player.joins(:team_players)
        .where.not(elo_rating: nil)
        .where('team_players.profession_id' => profession.id)
        .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
        .group('players.id', 'players.igname')
        .order('players.elo_rating DESC')
        .first(10)
      profession_stats[profession.name] = players
    end
    profession_stats
  end
end
