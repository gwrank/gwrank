class StatisticsController < ApplicationController
  def index
    # ELO statistics - top 10 players by ELO rating
    @top_elo_players = Player.joins(:team_players)
      .where.not(elo_rating: nil)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('players.id', 'players.igname')
      .having('COUNT(team_players.id) >= 5')
      .order('players.elo_rating DESC')
      .first(10)

    # Most improved players (players with biggest ELO increase recently)
    @most_improved_players = calculate_most_improved_players

    # Top 10 players by ELO for each profession
    @top_players_by_profession = calculate_top_players_by_profession

    # Guild ELO rankings
    @top_guilds_by_elo = calculate_guild_elo_rankings
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
      .having('COUNT(team_players.id) >= 10')
      .order('players.elo_rating DESC, players.updated_at DESC')
      .first(5)
  end

  def calculate_guild_elo_rankings
    # Calculate guild ELO based on average player ELO ratings
    Guild.joins(players: :team_players)
      .where('players.elo_rating IS NOT NULL')
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('guilds.id', 'guilds.name', 'guilds.tag')
      .having('COUNT(team_players.id) >= 10')
      .order('AVG(players.elo_rating) DESC')
      .select('guilds.id, guilds.name, guilds.tag, guilds.slug, AVG(players.elo_rating) as avg_elo, COUNT(team_players.id) as match_count')
      .first(10)
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
