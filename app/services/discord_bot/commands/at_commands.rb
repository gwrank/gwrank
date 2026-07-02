# app/services/discord_bot/commands/at_commands.rb
module DiscordBot
  module Commands
    class AtCommands
      QUEUE_SIZE = 8

      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        @bot.command(:at, description: 'to join the Automated Tournament queue for this server') do |event|
          handle_at_command(event)
        end

        @bot.command(:atplayers, description: 'to see players in the current AT queue for this server') do |event|
          handle_atplayers_command(event)
        end

        @bot.button(custom_id: 'at_register') do |event|
          handle_at_register_button(event)
        end

        @bot.button(custom_id: 'at_unregister') do |event|
          handle_at_unregister_button(event)
        end
      end

      private

      def handle_at_command(event)
        discord_server_id = event.server.id
        player = DiscordBot::FindOrCreatePlayer.call(event)

        event.send_message!(has_components: true) do |_, view|
          at_container(view, player, discord_server_id: discord_server_id)
        end
      end

      def handle_atplayers_command(event)
        discord_server_id = event.server.id
        at_registrations = AutomatedTournamentRegistration.current_for_server(discord_server_id).order(registered_at: :asc)

        message = "<@#{event.user.id}>, the current AT queue players for this server are:"
        if at_registrations.empty?
          message << "\nNo players in the queue yet."
        else
          at_registrations.each_with_index do |registration, index|
            message << "\n##{index + 1} <@#{registration.player.uid}>"
            message << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          end
        end

        at_count = at_registrations.count
        message << (at_count < QUEUE_SIZE ? "\nWe need #{QUEUE_SIZE - at_count} more players." : "\nTeam is full! (#{QUEUE_SIZE} players)")

        event.respond message
      end

      def handle_at_register_button(event)
        discord_server_id = event.server_id
        player = DiscordBot::FindOrCreatePlayer.call(event)

        if player.has_current_at_registration?(discord_server_id)
          event.respond(content: "You are already registered in the AT queue for this server, #{event.user.username}!", ephemeral: true)
          return
        end

        AutomatedTournamentRegistration.create!(player: player, discord_server_id: discord_server_id, registered_at: DateTime.now)
        at_count = AutomatedTournamentRegistration.current_for_server(discord_server_id).count

        event.interaction.update_message(has_components: true) do |_, view|
          at_container(view, player, discord_server_id: discord_server_id)
        end
        event.send_message(content: "You have been registered in the AT queue for this server, #{event.user.username}!", ephemeral: true)

        if at_count == QUEUE_SIZE
          event.channel.send_message "Team is full! #{QUEUE_SIZE} players registered for the Automated Tournament."
        elsif at_count > QUEUE_SIZE
          event.channel.send_message "AT queue now has #{at_count} players for this server."
        end
      end

      def handle_at_unregister_button(event)
        discord_server_id = event.server_id
        player = Player.find_by(uid: event.user.id)

        if player&.has_current_at_registration?(discord_server_id)
          player.current_at_registration(discord_server_id).update(unregistered_at: DateTime.now)
          event.interaction.update_message(has_components: true) do |_, view|
            at_container(view, player, discord_server_id: discord_server_id)
          end
          event.send_message(content: "You have been unregistered from the AT queue for this server, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered in the AT queue for this server, #{event.user.username}!", ephemeral: true)
        end
      end

      def at_container(view, player, discord_server_id: nil)
        view.container do |container|
          container.text_display(content: at_registration_panel_content(player, discord_server_id: discord_server_id))
          container.row do |row|
            row.button(label: 'Register', style: :success, custom_id: 'at_register')
            row.button(label: 'Unregister', style: :danger, custom_id: 'at_unregister')
          end
        end
      end

      def at_registration_panel_content(player, discord_server_id: nil)
        at_registrations = AutomatedTournamentRegistration.current_for_server(discord_server_id).order(registered_at: :asc)

        players = at_registrations.each_with_index.map do |registration, index|
          entry = "\n##{index + 1} <@#{registration.player.uid}>"
          entry << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          entry
        end

        message = "### Automated Tournament Registration Panel\n"
        message << "Current registered players for this server:\n"
        message << (players.empty? ? "No players registered yet.\n" : players.join("\n"))
        message << "\n"

        at_count = at_registrations.count
        message << (at_count < QUEUE_SIZE ? "We need #{QUEUE_SIZE - at_count} more players." : "Team is full! (#{QUEUE_SIZE} players)")
        message
      end
    end
  end
end
