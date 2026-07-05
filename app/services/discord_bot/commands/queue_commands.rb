module DiscordBot
  module Commands
    class QueueCommands
      QUEUE_SIZE = 16
      FORM_FIRST_SCRIM_LOCK_KEY = 'discord_bot.form_first_scrim'.hash & 0x7FFFFFFFFFFFFFFF

      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        register_schema
        register_dispatch

        @bot.button(custom_id: 'register') do |event|
          handle_register_button(event)
        end

        @bot.button(custom_id: 'unregister') do |event|
          handle_unregister_button(event)
        end
      end

      def dispatch(event)
        case event.subcommand
        when :open then handle_open(event)
        when :players then handle_players(event)
        when :reset then with_moderator(event) { handle_reset(event) }
        when :add then with_moderator(event) { handle_add(event) }
        when :remove then with_moderator(event) { handle_remove(event) }
        end
      end

      private

      def register_schema
        @bot.register_application_command(:queue, 'Manage the scrim registration queue', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:open, 'Post the scrim registration panel')
          cmd.subcommand(:players, 'List players in the current queue')
          cmd.subcommand(:reset, 'Reset the current queue (moderators only)')

          cmd.subcommand(:add, 'Add a player to the queue (moderators only)') do |sub|
            sub.string(:igname, "The player's in-game name", required: true)
          end

          cmd.subcommand(:remove, 'Remove a player from the queue (moderators only)') do |sub|
            sub.string(:igname, "The player's in-game name", required: true)
          end
        end
      end

      def register_dispatch
        handler = @bot.application_command(:queue)
        %i[open players reset add remove].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end

      def with_moderator(event)
        player = Player.find_by(uid: event.user.id)
        unless player&.is_moderator?
          event.respond(content: "<@#{event.user.id}>, you need to be a moderator to use this.", ephemeral: true)
          return
        end

        yield
      end

      def handle_open(event)
        event.respond(has_components: true) do |_, view|
          message_container(view)
        end
      end

      def handle_players(event)
        message = "<@#{event.user.id}>, the current players ordered by registration time are:"
        Registration.current_registrations.order(registered_at: :asc).each_with_index do |registration, index|
          player = registration.player
          message << "\n##{index + 1} <@#{player.uid}>"
          message << " (**#{player.igname}**)" if player.igname.present?
          message << " [#{player.professions_short_text}]" if player.professions_short_text.present?
        end
        event.respond(content: message)
      end

      def handle_reset(event)
        Registration.current_registrations.update_all(unregistered_at: DateTime.now)
        event.respond(content: "<@#{event.user.id}>, you successfully reset the current queue.\nPlayers can register again via the queue panel (*/queue open*).")
      end

      def handle_add(event)
        igname = event.options['igname']
        current_registrations = Registration.current_registrations
        player = Player.find_by(igname: igname)

        message =
          if player.present?
            if player.has_current_registration?
              "<@#{event.user.id}>, the player #{player.name} is already ##{current_registrations.count} in the current queue."
            else
              player.registrations.create(registered_at: DateTime.now)
              m = "<@#{event.user.id}>, the player #{player.name} is now ##{current_registrations.count} in the current queue for the next 8 hours."
              m << "\nIf he's out, a moderator can use */queue remove*."
              if current_registrations.count < QUEUE_SIZE
                m << "\nWe need #{QUEUE_SIZE - current_registrations.count} more players."
              elsif current_registrations.count.eql?(QUEUE_SIZE)
                m << "\nWe have 16 players!"
                m << "\nTo see the players list, you can use */queue players* or go on https://gwrank.com/scrims"
              end
              m
            end
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end

        event.respond(content: message)
      end

      def handle_remove(event)
        igname = event.options['igname']
        player = Player.find_by(igname: igname)

        message =
          if player.present?
            if player.has_current_registration?
              player.current_registration.update(unregistered_at: DateTime.now)
              "<@#{event.user.id}>, the player #{player.name} is not anymore in the current queue."
            else
              "<@#{event.user.id}>, the player #{player.name} was not in the current queue."
            end
          else
            "<@#{event.user.id}>, #{igname} is not found and needs to use */player register* first."
          end

        event.respond(content: message)
      end

      def handle_register_button(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)

        if player.has_current_registration?
          event.respond(content: "You are already registered, #{event.user.username}!", ephemeral: true)
        else
          player.registrations.create(registered_at: DateTime.now)
          # Only the very first scrim ever is auto-formed. Every scrim after
          # that (including reforming after a decided series) requires a
          # moderator to run /team new - see spec's Scrim Flow section.
          form_first_scrim_if_ready!
          event.interaction.update_message(has_components: true) do |_, view|
            message_container(view)
          end
          event.send_message(content: "You have been registered, #{event.user.username}!", ephemeral: true)
        end
      end

      # Discordrb dispatches each matched event handler (including button
      # clicks) on its own thread, so two near-simultaneous registrations
      # that both complete the queue could otherwise both pass the
      # count/exists? check and double-form teams. A non-blocking Postgres
      # advisory lock makes the check-and-form atomic: whichever thread
      # doesn't get the lock just skips forming, since the thread holding
      # it is already handling it. Failures are caught and logged so a
      # FormTeams error never strands the player's Discord confirmation.
      def form_first_scrim_if_ready!
        return unless Player.in_queue.count == QUEUE_SIZE

        with_form_first_scrim_lock do
          Scrims::FormTeams.call! if Player.in_queue.count == QUEUE_SIZE && !Scrim.exists?
        end
      rescue StandardError => e
        Rails.logger.error("Failed to auto-form first scrim: #{e.class}: #{e.message}")
      end

      def with_form_first_scrim_lock
        acquired = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{FORM_FIRST_SCRIM_LOCK_KEY})")
        return unless acquired

        yield
      ensure
        ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{FORM_FIRST_SCRIM_LOCK_KEY})") if acquired
      end

      def handle_unregister_button(event)
        player = Player.find_by(uid: event.user.id)

        if player&.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          event.interaction.update_message(has_components: true) do |_, view|
            message_container(view)
          end
          event.send_message(content: "You have been unregistered, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered, #{event.user.username}!", ephemeral: true)
        end
      end

      def message_container(view)
        view.container do |container|
          container.text_display(content: scrim_registration_panel_content)
          container.row do |row|
            row.button(label: 'Register', style: :success, custom_id: 'register')
            row.button(label: 'Unregister', style: :danger, custom_id: 'unregister')
          end
        end
      end

      def scrim_registration_panel_content
        players = Registration.current_registrations.order(registered_at: :asc).map.with_index do |registration, index|
          entry = ["\n##{index + 1} <@#{registration.player.uid}>"]
          entry << "(**#{registration.player.igname}**)" if registration.player.igname.present?
          entry << "[#{registration.player.professions_text}]" if registration.player.professions_text.present?
          entry.join(' ')
        end
        "### Scrim Registration Panel\nCurrent registered users:\n#{players.join("\n")}"
      end
    end
  end
end
