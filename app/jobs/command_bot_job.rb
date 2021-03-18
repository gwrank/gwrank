class CommandBotJob < ApplicationJob
  queue_as :default

  def perform(*args)
    bot = Discordrb::Commands::CommandBot.new token: ENV['DISCORD_BOT_TOKEN'], client_id: ENV['DISCORD_CLIENT_ID'], prefix: '!'

    bot.command :igname, description: 'to find the in-game name of a player', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
      if player.present? && player.starts_with?('<@!') && player.ends_with?('>')
        player = player.delete_prefix('<@!').delete_suffix('>')
        player = Player.find_by(uid: player)
        if player.present?
          message = "<@#{event.user.id}>, his in-game name is #{player.igname}"
        else
          message = "<@#{event.user.id}>, his in-game name is not found."
        end
      else
        message = "<@#{event.user.id}>, this is an invalid player."
      end
      event.respond message
    end

    bot.command :register, description: 'to register yourself in the current queue and your in-game name', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, *igname|
      message = ''
      player = Player.where(provider: 'discord', uid: event.user.id).first_or_create do |player|
        player.email = "#{event.user.id}@gwrank.com"
        player.password = Devise.friendly_token[0, 20]
        player.username = event.user.name
      end
      if player.igname.present?
        if igname.count > 1 && player.igname != igname
          igname = igname.join(' ')
          player.update(igname: igname)
          message << "\nYour known in-game name is #{player.igname}. You successfully updated it."
        else
          message << "\nYour known in-game name is #{player.igname}. If you want to update it, please type *!register In Game Name*"
        end
      else
        message << "\nYour in-game name is unknown on GWRank.com. If you want to add it, please type *!register In Game Name*"
      end
      if player.has_current_registration?
        message << "<@#{event.user.id}>, you are already in the current queue."
      else
        player.registrations.create(registered_at: DateTime.now)
        current_registrations = Registration.current_registrations
        message << "<@#{event.user.id}>, you are in the current queue for the next 8 hours."
        message << "\nIf you're out, please type *!unregister*"

        if current_registrations.count < 16
          players_required = 16 - current_registrations.count
          message << "\nWe need #{players_required} more players."
        elsif current_registrations.count.eql?(16)
          message << "\nWe have 16 players!"
          message << "\nTo see the players list, you can type *!players* or go on https://gwrank.com/scrims"
          message << "\nTo roll 100, captains can type *!roll*"
          message << "\nTo automatically designate captains, you can type *!newcaptains*"
        end
      end
      event.respond message
    end

    bot.command :add, description: 'to add a player in the current queue', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
      if player.present? && player.starts_with?('<@!') && player.ends_with?('>')
        player = player.delete_prefix('<@!').delete_suffix('>')
        player = Player.find_by(uid: player)
        if player.present?
          if player.has_current_registration?
            message = "<@#{event.user.id}>, the player #{player.name} is already in the current queue."
          else
            player.registrations.create(registered_at: DateTime.now)
            current_registrations = Registration.current_registrations
            message = "<@#{event.user.id}>, the player #{player.name} is now number #{current_registrations.count} in the current queue for the next 8 hours."
            message << "\nIf he's out, he have to type *!unregister*"

            if current_registrations.count < 16
              players_required = 16 - current_registrations.count
              message << "\nWe need #{players_required} more players."
            elsif current_registrations.count.eql?(16)
              message << "\nWe have 16 players!"
              message << "\nTo see the players list, you can type *!players* or go on https://gwrank.com/scrims"
              message << "\nTo roll 100, captains can type *!roll*"
              message << "\nTo automatically designate captains, you can type *!newcaptains*"
            end
          end
        else
          message = "<@#{event.user.id}>, the player is not found and have first to !register himself."
        end
      else
        message = "<@#{event.user.id}>, this is an invalid player."
      end
      event.respond message
    end

    bot.command :unregister, description: 'to unregister yourself from the current queue', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      player = Player.find_by(uid: event.user.id)
      if player
        if player.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          message = "<@#{event.user.id}>, you are not anymore in the current queue."
        else
          message = "<@#{event.user.id}>, you were not in the current queue."
        end
      else
        message = "<@#{event.user.id}>, you need to !register yourself first."
      end
      event.respond message
    end

    bot.command :remove, description: 'to remove a player from the current queue', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
      if player.present? && player.starts_with?('<@!') && player.ends_with?('>')
        player = player.delete_prefix('<@!').delete_suffix('>')
        player = Player.find_by(uid: player)
        if player.present?
          if player.has_current_registration?
            player.current_registration.update(unregistered_at: DateTime.now)
            message = "<@#{event.user.id}>, the player #{player.name} is not anymore in the current queue."
          else
            message = "<@#{event.user.id}>, the player #{player.name} was not in the current queue."
          end
        else
          message = "<@#{event.user.id}>, the player is not found and have first to !register himself."
        end
      else
        message = "<@#{event.user.id}>, this is an invalid player."
      end
      event.respond message
    end

    bot.command :afk, description: 'to be / add a player in afk mode', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
      if player.present? && player.starts_with?('<@!') && player.ends_with?('>')
        player = player.delete_prefix('<@!').delete_suffix('>')
        player = Player.find_by(uid: player)
        if player.present?
          if player.has_current_registration?
            player.current_registration.update(unregistered_at: DateTime.now)
            message = "<@#{event.user.id}>, the player #{player.name} is now in AFK mode, he have to write *!back* to be back in the current queue."
          else
            message = "<@#{event.user.id}>, the player #{player.name} is not in the current queue."
          end
        else
          message = "<@#{event.user.id}>, the player is not found and have first to !register himself."
        end
      else
        player = Player.find_by(uid: event.user.id)
        if player
          if player.has_current_registration?
            player.current_registration.update(unregistered_at: DateTime.now)
            message = "<@#{event.user.id}>, you are now in AFK mode."
          else
            message = "<@#{event.user.id}>, you were not in the current queue."
          end
        else
          message = "<@#{event.user.id}>, you need to !register yourself first."
        end
      end
      event.respond message
    end

    bot.command :back, description: 'to add yourself / a player again in the current queue', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
      if player.present? && player.starts_with?('<@!') && player.ends_with?('>')
        player = player.delete_prefix('<@!').delete_suffix('>')
        player = Player.find_by(uid: player)
        if player.present?
          if player.has_afk_registration?
            player.afk_registration.update(unregistered_at: DateTime.now)
            message = "<@#{event.user.id}>, the player #{player.name} is now back in the queue."
          else
            message = "<@#{event.user.id}>, the player #{player.name} was not in AFK mode."
          end
        else
          message = "<@#{event.user.id}>, the player is not found and have first to !register himself."
        end
      else
        player = Player.find_by(uid: event.user.id)
        if player
          if player.has_afk_registration?
            player.afk_registration.update(unregistered_at: nil)
            message = "<@#{event.user.id}>, welcome back!"
          else
            message = "<@#{event.user.id}>, you were not in the current queue."
          end
        else
          message = "<@#{event.user.id}>, you need to !register yourself first."
        end
      end
      event.respond message
    end

    bot.command :captains, description: 'to see the current captains', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      current_registrations = Registration.current_registrations
      if current_registrations.count >= 16
        scrim = Scrim.current_scrims.order(created_at: :desc).first
        message = "<@#{event.user.id}>, the current captains are @#{scrim.captain_a.username} and @#{scrim.captain_b.username}."
        message << "\nIf you want new captains, you can type *!newcaptains*"
      else
        players_required = 16 - current_registrations.count
        message = "<@#{event.user.id}>, we need #{players_required} more players to designate captains."
        message << "\nIf you really want new captains with the current queue, you can type *!forcenewcaptains*"
      end
      event.respond message
    end

    bot.command :newcaptains, description: 'to auto-designate new captains', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      current_registrations = Registration.current_registrations
      if current_registrations.count < 16
        players_required = 16 - current_registrations.count
        message = "<@#{event.user.id}>, we need #{players_required} more players to designate captains."
      elsif current_registrations.count >= 16
        captain_a = Registration.current_registrations.order(registered_at: :asc).first(16).sample.player
        captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).order(registered_at: :asc).first(15).sample.player
        scrim = Scrim.create!(
          captain_a: captain_a,
          captain_b: captain_b,
        )
        message = "<@#{event.user.id}>, the new captains are: <@#{scrim.captain_a.uid}> and <@#{scrim.captain_b.uid}>."
        message << "\nTo see the players list, you can type *!players* or go on https://gwrank.com/scrims"
        message << "\nTo roll 100, captains can type *!roll*"
        message << "\nTo automatically make teams with these new captains, you can type *!newteams*"
      end
      event.respond message
    end

    bot.command :forcenewcaptains, description: 'to auto-designate new captains even if you have less than 16 players', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      captain_a = Registration.current_registrations.order(registered_at: :asc).first(16).sample.player
      captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).order(registered_at: :asc).first(15).sample.player
      scrim = Scrim.create!(
        captain_a: captain_a,
        captain_b: captain_b,
      )
      message = "<@#{event.user.id}>, the new captains are: <@#{scrim.captain_a.uid}> and <@#{scrim.captain_b.uid}>."
      message << "\nTo see the players list, you can type *!players* or go on https://gwrank.com/scrims"
      message << "\nTo roll 100, captains can type *!roll*"
      event.respond message
    end

    bot.command :roll, description: 'to roll 100', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      message = "<@#{event.user.id}>, you rolled : "
      message << rand(0..100).to_s
      event.respond message
    end

    bot.command :players, description: 'to see players in the current queue', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      message = "<@#{event.user.id}>, if the player list is too long to be posted there, you can see it on https://gwrank.com/scrims"
      event.respond message

      message = "<@#{event.user.id}>, the current players ordered by registration time are :"
      Registration.current_registrations.order(registered_at: :asc).each do |registration|
        message << "\n<@#{registration.player.uid}>"
        message << ", in-game name #{registration.player.igname}" if registration.player.igname.present?
        message << ", #{registration.player.professions_text}" if registration.player.professions_text.present?
      end
      event.respond message
    end

    bot.command :newteams, description: 'to auto-designate new teams with current captains', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      player_ids = Player.in_queue.first(16).pluck(:id)
      selected_player_ids = []
      team_a_player_ids = []
      team_b_player_ids = []

      scrim = Scrim.order(created_at: :desc).first

      captain_a = scrim.captain_a
      team_a_player_ids << captain_a.id
      selected_player_ids << captain_a.id
      player_ids.delete(captain_a.id)

      captain_b = scrim.captain_b
      team_b_player_ids << captain_b.id
      selected_player_ids << captain_b.id
      player_ids.delete(captain_b.id)

      monks_count = Player.where('id IN (?)', player_ids).monks.count

      unless monks_count.eql?(0)
        monks_team_a = Player.where('id IN (?)', player_ids).monks.sample(monks_count / 2 + monks_count % 2)
        unless monks_team_a.count.eql?(0)
          team_a_player_ids << monks_team_a.pluck(:id)
          selected_player_ids << monks_team_a.pluck(:id)
          monks_team_a.pluck(:id).each do |monk_id|
            player_ids.delete(monk_id)
          end
        end

        monks_team_b = Player.where('id IN (?)', player_ids).monks.sample(monks_count / 2)
        unless monks_team_b.count.eql?(0)
          team_b_player_ids << monks_team_b.pluck(:id)
          selected_player_ids << monks_team_b.pluck(:id)
          monks_team_b.pluck(:id).each do |monk_id|
            player_ids.delete(monk_id)
          end
        end
      end

      frontliners_count = Player.where('id IN (?)', player_ids).frontliners.count
      unless frontliners_count.eql?(0)
        frontliners_team_a = Player.where('id IN (?)', player_ids).frontliners.sample(frontliners_count / 2)
        unless frontliners_team_a.count.eql?(0)
          team_a_player_ids << frontliners_team_a.pluck(:id)
          selected_player_ids << frontliners_team_a.pluck(:id)
          frontliners_team_a.pluck(:id).each do |frontliner_id|
            player_ids.delete(frontliner_id)
          end
        end

        frontliners_team_b = Player.where('id IN (?)', player_ids).frontliners.sample(frontliners_count / 2 + frontliners_count % 2)
        unless frontliners_team_b.count.eql?(0)
          team_b_player_ids << frontliners_team_b.pluck(:id)
          selected_player_ids << frontliners_team_b.pluck(:id)
          frontliners_team_b.pluck(:id).each do |frontliner_id|
            player_ids.delete(frontliner_id)
          end
        end
      end

      midliners_count = Player.where('id IN (?)', player_ids).midliners.count
      unless midliners_count.eql?(0)
        midliners_team_a = Player.where('id IN (?)', player_ids).midliners.sample(midliners_count / 2 + midliners_count % 2)
        unless midliners_team_a.count.eql?(0)
          team_a_player_ids << midliners_team_a.pluck(:id)
          selected_player_ids << midliners_team_a.pluck(:id)
          midliners_team_a.pluck(:id).each do |midliner_id|
            player_ids.delete(midliner_id)
          end
        end

        midliners_team_b = Player.where('id IN (?)', player_ids).midliners.sample(midliners_count / 2)
        unless midliners_team_b.count.eql?(0)
          team_b_player_ids << midliners_team_b.pluck(:id)
          selected_player_ids << midliners_team_b.pluck(:id)
          midliners_team_b.pluck(:id).each do |midliner_id|
            player_ids.delete(midliner_id)
          end
        end
      end

      other_players_count = Player.where('id IN (?)', player_ids).count
      unless other_players_count.eql?(0)
        team_a_player_ids = team_a_player_ids.flatten
        other_players_team_a = Player.where('id IN (?)', player_ids).sample(8 - team_a_player_ids.count)
        unless other_players_team_a.count.eql?(0)
          team_a_player_ids << other_players_team_a.pluck(:id)
          selected_player_ids << other_players_team_a.pluck(:id)
          other_players_team_a.pluck(:id).each do |other_player_id|
            player_ids.delete(other_player_id)
          end
        end

        team_b_player_ids = team_b_player_ids.flatten
        other_players_team_b = Player.where('id IN (?)', player_ids).sample(8 - team_b_player_ids.count)
        unless other_players_team_b.count.eql?(0)
          team_b_player_ids << other_players_team_b.pluck(:id)
          selected_player_ids << other_players_team_b.pluck(:id)
          other_players_team_b.pluck(:id).each do |other_player_id|
            player_ids.delete(other_player_id)
          end
        end
      end

      selected_player_ids = selected_player_ids.flatten
      team_a_player_ids = team_a_player_ids.flatten
      team_b_player_ids = team_b_player_ids.flatten

      message = 'Team A:'
      Player.where('id IN (?)', team_a_player_ids).each do |player|
        message << "\n<@#{player.uid}>"
        message << ', captain' if scrim.captain_a_id == player.id
        message << ", in-game name #{player.igname}" if player.igname.present?
        message << ", #{player.professions_text}" if player.professions_text.present?
      end
      event.respond message

      message = 'Team B:'
      Player.where('id IN (?)', team_b_player_ids).each do |player|
        message << "\n<@#{player.uid}>"
        message << ', captain' if scrim.captain_b_id == player.id
        message << ", in-game name #{player.igname}" if player.igname.present?
        message << ", #{player.professions_text}" if player.professions_text.present?
      end
      event.respond message

      message = 'Next players by order:'
      Player.where.not('players.id IN (?)', selected_player_ids).in_queue.each do |player|
        message << "\n<@#{player.uid}>"
        message << ", in-game name #{player.igname}" if player.igname.present?
        message << ", #{player.professions_text}" if player.professions_text.present?
      end
      event.respond message
    end

    bot.command :moveplayers, description: 'to automatically move players to the Scrimers voice channel (moderators only)', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      server = bot.server(ENV['DISCORD_SERVER_ID'])
      channel = bot.channel(ENV['DISCORD_SCRIMERS_VOICE_CHANNEL_ID'])

      player = Player.find_by(uid: event.user.id)
      if player.is_moderator?
        Registration.current_registrations.order(registered_at: :asc).first(16).each do |registration|
          user = bot.user(registration.player.uid)
          server.move(user, channel)
        end
        message = "<@#{event.user.id}>, the current first 16 players were moved to the Scrimers voice channel."
      else
        message = "<@#{event.user.id}>, you need to ask a moderator to move players."
      end

      event.respond message
    end

    bot.command :reset, description: 'to reset the current queue (moderators only)', channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event|
      player = Player.find_by(uid: event.user.id)
      if player.is_moderator?
        Registration.current_registrations.update_all(unregistered_at: DateTime.now)
        message = "<@#{event.user.id}>, you successfully reset the current queue."
        message << "\nPlayers can *!register* themselves again."
      else
        message = "<@#{event.user.id}>, you need to ask a moderator to reset the current queue."
      end
      event.respond message
    end

    # Run the bot in another thread in the background:
    bot.run(true)
  end
end
