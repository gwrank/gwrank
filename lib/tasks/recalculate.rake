namespace :recalculate do
  desc "Recalculate all player stats (DPM, K/D, ELO averages)"
  task stats: :environment do
    puts "Starting player stats recalculation..."

    start_time = Time.now
    player_count = 0

    Player.find_each(batch_size: 100) do |player|
      player.prepare_stats!
      player_count += 1
    end

    duration = Time.now - start_time
    puts "Completed recalculation for #{player_count} players in #{duration.round(2)} seconds"
  end

  desc "Recalculate stats for a specific player by ID"
  task player: :environment do
    player_id = ENV['PLAYER_ID'] || raise("PLAYER_ID environment variable required")
    player = Player.find_by(id: player_id)
    if player
      puts "Recalculating stats for player: #{player.username} (ID: #{player.id})"
      player.prepare_stats!
      puts "Average DPM: #{player.average_dpm}"
      puts "Average Dmg/Game: #{player.average_dmg_per_game}"
      puts "Average Deaths/Game: #{player.average_deaths_per_game}"
      puts "K/D Ratio: #{player.kd_ratio}"
      puts "Average Team ELO: #{player.average_team_elo}"
      puts "Average Opponent ELO: #{player.average_opponent_elo}"
    else
      puts "Player not found: #{player_id}"
    end
  end

  desc "Recalculate ELO and stats for all matches"
  task matches: :environment do
    puts "Starting ELO recalculation..."

    start_time = Time.now
    match_count = 0

    Match.where.not(winner_team_id: nil).where.not(loser_team_id: nil).find_each(batch_size: 50) do |match|
      match.calculate_elo!
      match.prepare_stats!
      match_count += 1
    end

    duration = Time.now - start_time
    puts "Completed ELO recalculation for #{match_count} matches in #{duration.round(2)} seconds"
  end

  desc "Recalculate team/opponent ELO for all players"
  task team_opponent_elo: :environment do
    puts "Starting team/opponent ELO recalculation..."

    start_time = Time.now
    player_count = 0

    # First, clear existing team/opponent ELO stats
    puts "Clearing existing team/opponent ELO stats..."
    TeamPlayerStat.where(stat_key: ['team_elo_at_match', 'opponent_elo_at_match']).delete_all

    # Recalculate ELO and stats for all matches to populate team/opponent ELO
    Match.where.not(winner_team_id: nil).where.not(loser_team_id: nil).find_each(batch_size: 50) do |match|
      match.calculate_elo!
      match.prepare_stats!
    end

    # Now recalculate player averages
    Player.find_each(batch_size: 100) do |player|
      player.prepare_stats!
      player_count += 1
    end

    duration = Time.now - start_time
    puts "Completed team/opponent ELO recalculation for #{player_count} players in #{duration.round(2)} seconds"
  end

  desc "Recalculate all stats including DPM, K/D, and ELO"
  task all: :environment do
    puts "Starting full stats recalculation..."

    start_time = Time.now

    # First, recalculate team/opponent ELO and stats for all matches
    puts "Step 1: Calculating team/opponent ELO and stats..."
    Match.where.not(winner_team_id: nil).where.not(loser_team_id: nil).find_each(batch_size: 50) do |match|
      match.calculate_elo!
      match.prepare_stats!
    end

    # Then recalculate all player stats
    puts "Step 2: Calculating player stats..."
    player_count = 0
    Player.find_each(batch_size: 100) do |player|
      player.prepare_stats!
      player_count += 1
    end

    duration = Time.now - start_time
    puts "\nFull recalculation completed!"
    puts "Processed #{player_count} players in #{duration.round(2)} seconds"
  end
end
