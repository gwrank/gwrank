# frozen_string_literal: true

namespace :players do
  task link_to_team_players: :environment do
    Player.all.each do |player|
      player.characters.each do |character|
        TeamPlayer.where(igname: character.igname).update_all(
          character_id: character.id,
          player_id: player.id
        )
      end
    end
  end

  task link_to_guilds: :environment do
    puts "Linking players to their most recent guilds..."

    Player.where(guild_id: nil).count.tap do |count|
      puts "Found #{count} players without a guild"
    end

    Player.find_each do |player|
      # Find the most recent team this player was on via team_players
      # Use the teams through association and join with matches
      latest_team = player.teams
        .joins(:match)
        .where.not(matches: { played_at: nil })
        .order('matches.played_at DESC')
        .first

      if latest_team && latest_team.guild
        player.update(guild_id: latest_team.guild_id)
      end
    end

    puts "Done linking players to guilds!"
  end
end
