module DiscordBot
  module Commands
    class RegistrationCommands
      QUEUE_SIZE = 16
      FORM_FIRST_SCRIM_LOCK_KEY = 'discord_bot.form_first_scrim'.hash & 0x7FFFFFFFFFFFFFFF

      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        @bot.command(:scrim, description: 'to start a scrim') do |event|
          handle_scrim_command(event)
        end

        @bot.command(:register, description: 'to register your in-game name') do |event, *igname|
          handle_register_command(event, igname)
        end

        @bot.button(custom_id: 'register') do |event|
          handle_register_button(event)
        end

        @bot.button(custom_id: 'unregister') do |event|
          handle_unregister_button(event)
        end

        @bot.command(:add, description: 'to add a player in the current queue (moderators only)') do |event, *igname|
          player = Player.find_by(uid: event.user.id)
          handle_add_command(event, igname.join(' ')) if player&.is_moderator?
        end

        @bot.command(:remove, description: 'to remove a player from the current queue (moderators only)') do |event, *igname|
          player = Player.find_by(uid: event.user.id)
          handle_remove_command(event, igname.join(' ')) if player&.is_moderator?
        end

        @bot.command(:afk, description: 'to add a player in afk mode (moderators only)') do |event, *igname|
          player = Player.find_by(uid: event.user.id)
          handle_afk_command(event, igname.join(' ')) if player&.is_moderator?
        end

        @bot.command(:back, description: 'to add a player again in the current queue (moderators only)') do |event, *igname|
          player = Player.find_by(uid: event.user.id)
          handle_back_command(event, igname.join(' ')) if player&.is_moderator?
        end

        @bot.command(:reset, description: 'to reset the current queue (moderators only)') do |event|
          handle_reset_command(event)
        end

        @bot.command(:players, description: 'to see players in the current queue') do |event|
          handle_players_command(event)
        end
      end

      private

      def handle_scrim_command(event)
        event.send_message!(has_components: true) do |_, view|
          message_container(view)
        end
      end

      def handle_register_button(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)

        if player.has_current_registration?
          event.respond(content: "You are already registered, #{event.user.username}!", ephemeral: true)
        else
          player.registrations.create(registered_at: DateTime.now)
          # Only the very first scrim ever is auto-formed. Every scrim after
          # that (including reforming after a decided series) requires a
          # moderator to run !newteams - see spec's Scrim Flow section.
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

      def handle_register_command(event, igname)
        message = ''
        player = DiscordBot::FindOrCreatePlayer.call(event)

        if player.igname.present?
          if igname.count > 1 && player.igname != igname
            igname = igname.join(' ')
            player.update(igname: igname)
            message << "\nYour known in-game name is **#{player.igname}**."
          else
            message << "\nYour known in-game name is **#{player.igname}**. If you want to update it, please type *!register* **Your In Game Name**"
          end
        else
          if igname.count > 1 && player.igname != igname
            igname = igname.join(' ')
            player.update(igname: igname)
            message << "\nYour known in-game name is **#{player.igname}**. You successfully updated it."
          else
            message << "\nYour in-game name is unknown. To be easily guested, please type *!register* **Your In Game Name**"
          end
        end

        event.respond message
      end

      def handle_add_command(event, igname)
        current_registrations = Registration.current_registrations
        if igname.present?
          player = Player.find_by(igname: igname)
          if player.present?
            if player.has_current_registration?
              message = "<@#{event.user.id}>, the player #{player.name} is already ##{current_registrations.count} in the current queue."
            else
              player.registrations.create(registered_at: DateTime.now)
              message = "<@#{event.user.id}>, the player #{player.name} is now ##{current_registrations.count} in the current queue for the next 8 hours."
              message << "\nIf he's out, he have to type *!unregister*"

              if current_registrations.count < QUEUE_SIZE
                players_required = QUEUE_SIZE - current_registrations.count
                message << "\nWe need #{players_required} more players."
              elsif current_registrations.count.eql?(QUEUE_SIZE)
                message << "\nWe have 16 players!"
                message << "\nTo see the players list, you can type *!players* or go on https://gwrank.com/scrims"
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

      def handle_remove_command(event, igname)
        if igname.present?
          player = Player.find_by(igname: igname)
          if player.present?
            if player.has_current_registration?
              player.current_registration.update(unregistered_at: DateTime.now)
              message = "<@#{event.user.id}>, the player #{player.name} is not anymore in the current queue."
            else
              message = "<@#{event.user.id}>, the player #{player.name} was not in the current queue."
            end
          else
            message = "<@#{event.user.id}>, #{igname} is not found and have first to !register himself."
          end
        else
          message = "<@#{event.user.id}>, #{igname} is an invalid player."
        end
        event.respond message
      end

      def handle_afk_command(event, player)
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

      def handle_back_command(event, player)
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

      def handle_reset_command(event)
        player = Player.find_by(uid: event.user.id)
        if player&.is_moderator?
          Registration.current_registrations.update_all(unregistered_at: DateTime.now)
          message = "<@#{event.user.id}>, you successfully reset the current queue."
          message << "\nPlayers can *!register* themselves again."
        else
          message = "<@#{event.user.id}>, you need to ask a moderator to reset the current queue."
        end
        event.respond message
      end

      def handle_players_command(event)
        message = "<@#{event.user.id}>, the current players ordered by registration time are:"
        Registration.current_registrations.order(registered_at: :asc).each_with_index do |registration, index|
          player = registration.player
          message << "\n##{index + 1} <@#{player.uid}>"
          message << " (**#{player.igname}**)" if player.igname.present?
          message << " [#{player.professions_short_text}]" if player.professions_short_text.present?
        end
        event.respond message
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
