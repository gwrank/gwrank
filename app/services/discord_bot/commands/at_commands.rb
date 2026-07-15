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
        register_schema
        register_dispatch

        @bot.button(custom_id: 'at_register') do |event|
          handle_at_register_button(event)
        end

        @bot.button(custom_id: 'at_unregister') do |event|
          handle_at_unregister_button(event)
        end
      end

      def dispatch(event)
        case event.subcommand
        when :schedule then handle_schedule(event)
        when :next then handle_next(event)
        when :join then handle_join(event)
        when :players then handle_players(event)
        end
      end

      private

      def register_schema
        @bot.register_application_command(:at, 'Manage the Automated Tournament queue', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:schedule, 'Set which daily AT slot (a/b/c) this server tracks') do |sub|
            sub.string(:timezone, 'Which of the 3 daily AT occurrences to track', required: true,
                       choices: { 'A (earliest)' => 'a', 'B (middle)' => 'b', 'C (latest)' => 'c' })
          end
          cmd.subcommand(:next, 'Show time until the next scheduled AT and registration window status')
          cmd.subcommand(:join, 'Post the Automated Tournament registration panel')
          cmd.subcommand(:players, 'List players in the current AT queue')
        end
      end

      def register_dispatch
        handler = @bot.application_command(:at)
        %i[schedule next join players].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end

      def handle_schedule(event)
        discord_server_id = event.server.id
        new_timezone = event.options['timezone']

        schedule = AutomatedTournamentSchedule.find_or_initialize_by(discord_server_id: discord_server_id)
        timezone_changed = schedule.timezone.present? && schedule.timezone != new_timezone
        schedule.timezone = new_timezone
        schedule.channel_id = event.channel.id
        schedule.last_reminded_on = nil if timezone_changed
        schedule.save!

        next_occ = schedule.next_occurrence
        event.respond(content: "<@#{event.user.id}>, this server now tracks AT slot **#{new_timezone}**; reminders will post in this channel. Next AT: #{next_occ.strftime('%Y-%m-%d %H:%M UTC')}.")
      end

      def handle_next(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(discord_server_id: discord_server_id)
        return schedule_required_message(event) unless schedule

        now = Time.now.utc
        next_occ = schedule.next_occurrence(from: now)

        message =
          if next_occ > now
            "<@#{event.user.id}>, the next AT (slot #{schedule.timezone.upcase}) starts in #{format_duration(next_occ - now)} (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')})."
          else
            boundary = schedule.window_boundary(from: now)
            "<@#{event.user.id}>, the AT (slot #{schedule.timezone.upcase}) started #{format_duration(now - next_occ)} ago. Registration window closes in #{format_duration(boundary - now)}."
          end

        event.respond(content: message)
      end

      def handle_join(event)
        discord_server_id = event.server.id
        return unless require_schedule!(event, discord_server_id)

        player = DiscordBot::FindOrCreatePlayer.call(event)

        event.respond(has_components: true) do |_, view|
          at_container(view, player, discord_server_id: discord_server_id)
        end
      end

      def handle_players(event)
        discord_server_id = event.server.id
        return unless require_schedule!(event, discord_server_id)

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

        event.respond(content: message)
      end

      def handle_at_register_button(event)
        discord_server_id = event.server_id
        return unless require_schedule!(event, discord_server_id, ephemeral: true)

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
        return unless require_schedule!(event, discord_server_id, ephemeral: true)

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

      def require_schedule!(event, discord_server_id, ephemeral: false)
        return true if AutomatedTournamentSchedule.exists?(discord_server_id: discord_server_id)

        event.respond(content: "<@#{event.user.id}>, this server hasn't set an AT schedule yet. Run */at schedule* first.", ephemeral: ephemeral)
        false
      end

      def schedule_required_message(event)
        event.respond(content: "<@#{event.user.id}>, this server hasn't set an AT schedule yet. Run */at schedule* first.")
      end

      def format_duration(seconds)
        total_minutes = (seconds / 60).round
        hours, minutes = total_minutes.divmod(60)
        hours.positive? ? "#{hours}h #{minutes}m" : "#{minutes}m"
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
