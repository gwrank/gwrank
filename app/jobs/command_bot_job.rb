class CommandBotJob < ApplicationJob
  queue_as :default

  def perform(*args)
    bot = Discordrb::Commands::CommandBot.new token: ENV['DISCORD_BOT_TOKEN'], client_id: ENV['DISCORD_CLIENT_ID'], prefix: '!'

    bot.command :igname, channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
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

    bot.command :add, channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
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
          message = "<@#{event.user.id}>, the player is not found and have first to Log in with Discord on https://gwrank.com."
        end
      else
        message = "<@#{event.user.id}>, this is an invalid player."
      end
      event.respond message
    end

    bot.command :remove, channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
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
          message = "<@#{event.user.id}>, the player is not found and have first to Log in with Discord on https://gwrank.com."
        end
      else
        message = "<@#{event.user.id}>, this is an invalid player."
      end
      event.respond message
    end

    bot.command :afk, channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
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
          message = "<@#{event.user.id}>, the player is not found and have first to Log in with Discord on https://gwrank.com."
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
          message = "<@#{event.user.id}>, you need to log in with Discord on https://gwrank.com to be in AFK mode."
        end
      end
      event.respond message
    end

    bot.command :back, channels: [ENV['DISCORD_COMMAND_CHANNEL']] do |event, player|
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
          message = "<@#{event.user.id}>, the player is not found and have first to Log in with Discord on https://gwrank.com."
        end
      else
        player = Player.find_by(uid: event.user.id)
        if player
          if player.has_afk_registration?
            player.afk_registration.update(unregistered_at: nil)
            message = "<@#{event.user.id}>, you are now back in the queue."
          else
            message = "<@#{event.user.id}>, you were not in the current queue."
          end
        else
          message = "<@#{event.user.id}>, you need to log in with Discord on https://gwrank.com to be in AFK mode."
        end
      end
      event.respond message
    end

    # Run the bot in another thread in the background:
    bot.run(true)
  end
end
