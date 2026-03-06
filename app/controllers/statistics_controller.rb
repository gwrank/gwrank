class StatisticsController < ApplicationController
  def index
    @best_cpm_warriors = Player.warriors.order(average_warrior_cpm: :desc).first(10)

    @most_picked_skills = TeamPlayerSkill.joins(:skill)
      .where.not('skills.name': 'No Skill')
      .where.not('skills.name': 'Unknown')
      .group('skills.name')
      .order(count: :desc)
      .count
      .first(10)

    @trims_guilds = Guild.where('gold_trims_count >= ?', 1)
      .order(gold_trims_count: :desc, silver_trims_count: :desc, bronze_trims_count: :desc)
      .first(16)

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

  def calculate_guild_elo_rankings
    # Calculate guild ELO based on average player ELO ratings
    Guild.joins(players: :team_players)
      .merge(TeamPlayer.joins(:team).merge(Team.where.not(match_id: nil)))
      .group('guilds.id', 'guilds.name', 'guilds.tag')
      # FIXME: .having('COUNT(team_players.id) >= 10')
      .order('AVG(players.elo_rating) DESC')
      .select('guilds.id, guilds.name, guilds.tag, guilds.slug, AVG(players.elo_rating) as avg_elo, COUNT(team_players.id) as match_count')
      .first(10)
  end
end
