class BotJob < ApplicationJob
  queue_as :default

  def perform(*args)
    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']

    bot.message(with_text: '!help') do |event|
      event.respond "@#{event.user.name}, the command list is:"
      event.respond "!register : to register yourself in the current queue for the next 4 hours."
      event.respond "!unregister : to unregister yourself."
      event.respond "!captains : to designate or see current captains."
      event.respond "!newcaptains : to designate new captains."
      event.respond "!teams : to designate teams."
    end

    bot.message(with_text: '!register') do |event|
      player = Player.find_by(uid: event.user.id)
      if player
        if player.has_current_registration?
          event.respond "@#{event.user.name}, you are already in the current queue."
        else
          player.registrations.create(registered_at: DateTime.now)
          event.respond "@#{event.user.name}, you are now in the current queue for the next 4 hours."
        end

        current_registrations = Registration.current_registrations
        if current_registrations.count < 16
          players_required = 16 - current_registrations.count
          event.respond "@#{event.user.name}, we need #{players_required} more players to designate captains."
        elsif current_registrations.count.eql?(16)
          event.respond "@#{event.user.name}, you are the 16th player! I proceed to the captains designation..."
          captain_a = Registration.current_registrations.order(registered_at: :asc).first(16).sample.player
          captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).order(registered_at: :asc).first(15).sample.player
          scrim = Scrim.create!(
            captain_a: captain_a,
            captain_b: captain_b,
          )
          event.respond "@#{event.user.name}, the captains are @#{scrim.captain_a.username} and @#{scrim.captain_b.username}."
          event.respond "@#{scrim.captain_a.username} and @#{scrim.captain_b.username}, the players are :"
          Registration.current_registrations.order(registered_at: :asc).each_with_index do |registration|
            event.respond "@#{registration.player.username}, with in-game name #{registration.player.igname}, who play #{registration.player.professions_text} at #{registration.player.guild&.name}, player ##{index}. His profile is accessible on https://gwrank.com/p/#{registration.player.slug}"
          end
        elsif current_registrations.count > 16
          event.respond "@#{event.user.name}, you are on the waiting list."
        end
      else
        event.respond "@#{event.user.name}, you need to log in with Discord on https://gwrank.com to register yourself."
      end
    end

    bot.message(with_text: '!unregister') do |event|
      player = Player.find_by(uid: event.user.id)
      if player
        if player.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          event.respond "@#{event.user.name}, you are not anymore in the current queue."
        else
          event.respond "@#{event.user.name}, you were not in the current queue."
        end
      else
        event.respond "@#{event.user.name}, you need to log in with Discord on https://gwrank.com to unregister yourself."
      end
    end

    bot.message(with_text: '!captains') do |event|
      current_registrations = Registration.current_registrations
      if current_registrations.count >= 16
        scrim = Scrim.current_scrims.first
        event.respond "@#{event.user.name}, the current captains are @#{scrim.captain_a.username} and @#{scrim.captain_b.username}."
      else
        players_required = 16 - current_registrations.count
        event.respond "@#{event.user.name}, we need #{players_required} more players to designate captains."
      end
    end

    bot.message(with_text: '!newcaptains') do |event|
      current_registrations = Registration.current_registrations
      if current_registrations.count < 16
        players_required = 16 - current_registrations.count
        event.respond "@#{event.user.name}, we need #{players_required} more players to designate captains."
      elsif current_registrations.count >= 16
        captain_a = Registration.current_registrations.order(registered_at: :asc).first(16).sample.player
        captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).order(registered_at: :asc).first(15).sample.player
        Scrim.create!(
          captain_a: captain_a,
          captain_b: captain_b,
        )
        event.respond "@#{event.user.name}, the captains are @#{scrim.captain_a.username} and @#{scrim.captain_b.username}."
        event.respond "@#{scrim.captain_a.username} and @#{scrim.captain_b.username}, the players are :"
        Registration.current_registrations.order(registered_at: :asc).each_with_index do |registration|
          event.respond "@#{registration.player.username}, with in-game name #{registration.player.igname}, who play #{registration.player.professions_text} at #{registration.player.guild&.name}, player ##{index}. His profile is accessible on https://gwrank.com/p/#{registration.player.slug}"
        end
      end
    end

    bot.message(with_text: '!teams') do |event|
      event.respond "This command is in development."

      # count = Player.count
      # count -= 1 if count % 2 == 1
      # players_per_team = count / 2
      # first_team_players = Player.all.sample(players_per_team)
      # first_team_players_ignames = ''
      # first_team_players.each do |player|
      #   first_team_players_ignames = [first_team_players_ignames, player.igname].join(', ')
      # end
      # event.respond "The first team players are: #{first_team_players_ignames}"
      # second_team_players = Player.where.not('id IN (?)', first_team_players).sample(players_per_team)
      # second_team_players_ignames = ''
      # second_team_players.each do |player|
      #   second_team_players_ignames = [second_team_players_ignames, player.igname].join(', ')
      # end
      # event.respond "The second team players are: #{second_team_players_ignames}"
    end

    # Run the bot in another thread in the background:
    bot.run(true)
  end
end
