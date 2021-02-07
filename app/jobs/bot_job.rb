class BotJob < ApplicationJob
  queue_as :default

  def perform(*args)
    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']

    bot.message(with_text: '!help', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      message << "<@#{event.user.id}>, the command list is:"
      message << "\n!register : to register yourself in the current queue for the next 8 hours."
      message << "\n!unregister : to unregister yourself."
      message << "\n!captains : to designate or see current captains."
      message << "\n!newcaptains : to designate new captains."
      message << "\n!players : to see current players."
      message << "\n!teams : to designate teams."
      message << "\n!roll : to roll 100."
      event.respond message
    end

    bot.message(with_text: '!register', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      player = Player.find_by(uid: event.user.id)
      if player
        if player.has_current_registration?
          message << "<@#{event.user.id}>, you are already in the current queue."
        else
          player.registrations.create(registered_at: DateTime.now)
          message << "<@#{event.user.id}>, you are now in the current queue for the next 8 hours. Type *!unregister* if you're off"

          current_registrations = Registration.current_registrations
          if current_registrations.count < 16
            players_required = 16 - current_registrations.count
            message << "\n<@#{event.user.id}>, we need #{players_required} more players to designate captains."
          elsif current_registrations.count.eql?(16)
            message << "\n<@#{event.user.id}>, you are the 16th player! I proceed to the captains designation..."
            captain_a = Registration.current_registrations.order(registered_at: :asc).first(16).sample.player
            captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).order(registered_at: :asc).first(15).sample.player
            scrim = Scrim.create!(
              captain_a: captain_a,
              captain_b: captain_b,
            )
            message << "\n<@#{event.user.id}>, the captains are <@#{scrim.captain_a.uid}> and <@#{scrim.captain_b.uid}>."
            message << "\nType !teams to designate teams!"
          elsif current_registrations.count > 16
            message << "\n<@#{event.user.id}>, you are on the waiting list."
          end
        end
      else
        message << "<@#{event.user.id}>, you need to log in with Discord on https://gwrank.com to register yourself."
      end
      event.respond message
    end

    bot.message(with_text: '!unregister', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      player = Player.find_by(uid: event.user.id)
      if player
        if player.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          message << "<@#{event.user.id}>, you are not anymore in the current queue."
        else
          message << "<@#{event.user.id}>, you were not in the current queue."
        end
      else
        message << "<@#{event.user.id}>, you need to log in with Discord on https://gwrank.com to unregister yourself."
      end
      event.respond message
    end

    bot.message(with_text: '!captains', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      current_registrations = Registration.current_registrations
      if current_registrations.count >= 16
        scrim = Scrim.current_scrims.order(created_at: :desc).first
        message << "<@#{event.user.id}>, the current captains are @#{scrim.captain_a.username} and @#{scrim.captain_b.username}."
      else
        players_required = 16 - current_registrations.count
        message << "<@#{event.user.id}>, we need #{players_required} more players to designate captains."
      end
      event.respond message
    end

    bot.message(with_text: '!newcaptains', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      current_registrations = Registration.current_registrations
      if current_registrations.count < 16
        players_required = 16 - current_registrations.count
        message << "<@#{event.user.id}>, we need #{players_required} more players to designate captains."
      elsif current_registrations.count >= 16
        captain_a = Registration.current_registrations.order(registered_at: :asc).first(16).sample.player
        captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).order(registered_at: :asc).first(15).sample.player
        scrim = Scrim.create!(
          captain_a: captain_a,
          captain_b: captain_b,
        )
        message << "<@#{event.user.id}>, the captains are @#{scrim.captain_a.username} and @#{scrim.captain_b.username}."
        message << "\n@#{scrim.captain_a.username} and @#{scrim.captain_b.username}, the players are :"
        Registration.current_registrations.order(registered_at: :asc).each do |registration|
          message << "\n@#{registration.player.username}, in-game name #{registration.player.igname}, #{registration.player.professions_text} at #{registration.player.guild&.name}. Profile page: https://gwrank.com/p/#{registration.player.slug}"
        end
      end
      event.respond message
    end

    bot.message(with_text: '!players', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      message << "<@#{event.user.id}>, the current players are :"
      Registration.current_registrations.order(registered_at: :asc).each do |registration|
        message << "\n@#{registration.player.username}, in-game name #{registration.player.igname}, #{registration.player.professions_text} at #{registration.player.guild&.name}. Profile page: https://gwrank.com/p/#{registration.player.slug}"
      end
      event.respond message
    end

    bot.message(with_text: '!roll', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
      message = ''
      message << "<@#{event.user.id}>, you rolled : "
      message << rand(0..100).to_s
      event.respond message
    end

    bot.message(with_text: '!teams', in: ENV['DISCORD_COMMAND_CHANNEL']) do |event|
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

      message = 'Team A :'
      Player.where('id IN (?)', team_a_player_ids).each do |player|
        message << "\n<@#{player.uid}>"
        message << ', captain' if scrim.captain_a_id == player.id
        message << ", in-game name #{player.igname}" if player.igname.present?
        message << ", #{player.professions_text}" if player.professions_text.present?
        message << ". Profile page: https://gwrank.com/p/#{player.slug}"
      end
      event.respond message

      message = 'Team B :'
      Player.where('id IN (?)', team_b_player_ids).each do |player|
        message << "\n<@#{player.uid}>"
        message << ', captain' if scrim.captain_b_id == player.id
        message << ", in-game name #{player.igname}" if player.igname.present?
        message << ", #{player.professions_text}" if player.professions_text.present?
        message << ". Profile page: https://gwrank.com/p/#{player.slug}"
      end
      event.respond message

      message = 'Next players by order:'
      Player.where.not('players.id IN (?)', selected_player_ids).in_queue.each do |player|
        message << "\n<@#{player.uid}>"
        message << ", in-game name #{player.igname}" if player.igname.present?
        message << ", #{player.professions_text}" if player.professions_text.present?
        message << ". Profile page: https://gwrank.com/p/#{player.slug}"
      end
      event.respond message
    end

    # Run the bot in another thread in the background:
    bot.run(true)
  end
end