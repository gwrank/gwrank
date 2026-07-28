module DiscordBot
  module Commands
    class ScrimCommands
      include ModeratorGate

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
        register_buttons
      end

      def register_schema
        @bot.register_application_command(:scrim, 'Manage scrim registration and teams', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          # Queue management
          cmd.subcommand(:register, 'Register for the scrim queue')
          cmd.subcommand(:unregister, 'Unregister from the scrim queue')
          cmd.subcommand(:queue, 'Show current scrim queue')
          cmd.subcommand(:panel, 'Show scrim registration panel')
          cmd.subcommand(:reset, 'Reset the current queue (moderators only)')

          cmd.subcommand(:add, 'Add a player to the queue (moderators only)') do |sub|
            sub.string(:igname, "The player's in-game name", required: true)
          end

          cmd.subcommand(:remove, 'Remove a player from the queue (moderators only)') do |sub|
            sub.string(:igname, "The player's in-game name", required: true)
          end

          cmd.subcommand(:afk, 'Mark a player AFK (moderators only)') do |sub|
            sub.user(:member, 'The player to mark AFK (defaults to yourself)', required: false)
          end

          cmd.subcommand(:back, 'Bring a player back from AFK (moderators only)') do |sub|
            sub.user(:member, 'The player to bring back (defaults to yourself)', required: false)
          end

          # Team management
          cmd.subcommand_group(:team, 'Team management commands') do |team_cmd|
            team_cmd.subcommand(:captains, 'See the current captains')
            team_cmd.subcommand(:roll, 'Roll 0-100')
            team_cmd.subcommand(:new, 'Form new teams for the next series (moderators only)')
            team_cmd.subcommand(:win, 'Record a game win for a team (moderators only)') do |sub|
              sub.string(:side, 'Which team won', required: true, choices: { 'Team A' => 'a', 'Team B' => 'b' })
            end
            team_cmd.subcommand(:move, 'Move the current queue to the Scrimers voice channel (moderators only)')
          end
        end
      end

      def register_dispatch
        handler = @bot.application_command(:scrim)
        %i[register unregister queue panel reset add remove afk back].each { |name| handler.subcommand(name) { |event| dispatch(event) } }

        handler.group(:team) do |team_builder|
          %i[captains roll new win move].each { |name| team_builder.subcommand(name) { |event| dispatch(event) } }
        end
      end

      def register_buttons
        @bot.button(custom_id: 'scrim_register') do |event|
          handle_register_button(event)
        end

        @bot.button(custom_id: 'scrim_unregister') do |event|
          handle_unregister_button(event)
        end

        @bot.button(custom_id: 'scrim_afk') do |event|
          handle_afk_button(event)
        end

        @bot.button(custom_id: 'scrim_back') do |event|
          handle_back_button(event)
        end

        @bot.button(custom_id: 'scrim_reset') do |event|
          with_moderator(event) { handle_reset_button(event) }
        end
      end

      def dispatch(event)
        case event.subcommand
        when :register then handle_register(event)
        when :unregister then handle_unregister(event)
        when :queue then handle_queue(event)
        when :panel then handle_panel(event)
        when :reset then with_moderator(event) { handle_reset(event) }
        when :add then with_moderator(event) { handle_add(event) }
        when :remove then with_moderator(event) { handle_remove(event) }
        when :afk then with_moderator(event) { handle_afk(event) }
        when :back then with_moderator(event) { handle_back(event) }
        when :captains then handle_captains(event)
        when :roll then handle_roll(event)
        when :new then with_moderator(event) { handle_new(event) }
        when :win then with_moderator(event) { handle_win(event) }
        when :move then with_moderator(event) { handle_move(event) }
        end
      end

      private

      # Queue management methods (migrated from QueueCommands)

      def handle_register(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)

        if player.has_current_registration?
          event.respond(content: "You are already registered, #{event.user.username}!", ephemeral: true)
        else
          player.registrations.create(registered_at: DateTime.now)
          form_first_scrim_if_ready!
          ScrimPanelManager.instance.update_all_panels(@bot)

          event.respond(content: "You have been registered, #{event.user.username}!", ephemeral: true)
        end
      end

      def handle_unregister(event)
        player = Player.find_by(uid: event.user.id)

        if player&.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          ScrimPanelManager.instance.update_all_panels(@bot)
          event.respond(content: "You have been unregistered, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered, #{event.user.username}!", ephemeral: true)
        end
      end

      def handle_queue(event)
        message = "<@#{event.user.id}>, the current players ordered by registration time are:"
        Registration.current_registrations.order(registered_at: :asc).each_with_index do |registration, index|
          player = registration.player
          message << "\n##{index + 1} <@#{player.uid}>"
          message << " (**#{player.igname}**)" if player.igname.present?
          message << " [#{player.professions_short_text}]" if player.professions_short_text.present?
        end
        event.respond(content: message)
      end

      def handle_panel(event)
        panel_manager = ScrimPanelManager.instance
        
        # Send the panel message with components and track it
        # Note: When using has_components: true, we cannot pass content: separately
        # The content must be inside the components
        event.respond(has_components: true) do |_, view|
          # Build the panel components directly on the view
          view.container do |container|
            container.text_display(content: panel_manager.panel_content)
            
            # Row 1: Register/Unregister
            container.row do |row|
              row.button(label: 'Register', style: :success, custom_id: 'scrim_register')
              row.button(label: 'Unregister', style: :danger, custom_id: 'scrim_unregister')
            end
            
            # Row 2: AFK/Back
            container.row do |row|
              row.button(label: 'AFK', style: :secondary, custom_id: 'scrim_afk')
              row.button(label: 'Back (from AFK)', style: :secondary, custom_id: 'scrim_back')
            end
            
            # Row 3: Reset (moderators only)
            container.row do |row|
              row.button(label: 'Reset Queue', style: :danger, custom_id: 'scrim_reset')
            end
          end
        end
        
        # Get the message from the event and track it
        # For application command responses, try to get the message from various sources
        
        server_id = event.server.id
        message = nil
        
        # Try event.message first
        message = event.message rescue nil
        
        # If not available, try event.interaction.message
        if message.nil?
          message = event.interaction.message rescue nil
        end
        
        # If we have a message, track it
        if message
          Rails.logger.info("Tracking panel: server=#{server_id}, channel=#{message.channel.id}, message=#{message.id}")
          panel_manager.add_panel(server_id, message.channel.id, message.id)
        else
          # If we can't get the message, log it
          Rails.logger.warn("Could not get message for panel on server #{server_id}. Panel will not be tracked for updates.")
        end
      end

      def handle_reset(event)
        Registration.current_registrations.update_all(unregistered_at: DateTime.now)
        ScrimPanelManager.instance.update_all_panels(@bot)
        event.respond(content: "<@#{event.user.id}>, you successfully reset the current queue.\nPlayers can register again via the queue panel (*/scrim register*).")
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
              ScrimPanelManager.instance.update_all_panels(@bot)
              m = "<@#{event.user.id}>, the player #{player.name} is now ##{current_registrations.count} in the current queue for the next 8 hours."
              m << "\nIf he's out, a moderator can use */scrim remove*."
              if current_registrations.count < QUEUE_SIZE
                m << "\nWe need #{QUEUE_SIZE - current_registrations.count} more players."
              elsif current_registrations.count.eql?(QUEUE_SIZE)
                m << "\nWe have 16 players!"
                m << "\nTo see the players list, you can use */scrim queue* or go on https://gwrank.com/scrims"
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
              ScrimPanelManager.instance.update_all_panels(@bot)
              "<@#{event.user.id}>, the player #{player.name} is not anymore in the current queue."
            else
              "<@#{event.user.id}>, the player #{player.name} was not in the current queue."
            end
          else
            "<@#{event.user.id}>, #{igname} is not found and needs to use */player register* first."
          end

        event.respond(content: message)
      end

      def handle_afk(event)
        self_target = event.options['member'].blank?
        player = Player.find_by(uid: self_target ? event.user.id : event.options['member'])

        message =
          if player&.has_current_registration?
            player.current_registration.update(unregistered_at: DateTime.now)
            ScrimPanelManager.instance.update_all_panels(@bot)
            self_target ? "<@#{event.user.id}>, you are now in AFK mode." : "<@#{event.user.id}>, the player #{player.name} is now in AFK mode, he can use */scrim back* to return."
          elsif player
            self_target ? "<@#{event.user.id}>, you were not in the current queue." : "<@#{event.user.id}>, the player #{player.name} is not in the current queue."
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end

        event.respond(content: message)
      end

      def handle_back(event)
        self_target = event.options['member'].blank?
        player = Player.find_by(uid: self_target ? event.user.id : event.options['member'])

        message =
          if player&.has_afk_registration?
            player.afk_registration.update(unregistered_at: self_target ? nil : DateTime.now)
            ScrimPanelManager.instance.update_all_panels(@bot)
            self_target ? "<@#{event.user.id}>, welcome back!" : "<@#{event.user.id}>, the player #{player.name} is now back in the queue."
          elsif player
            self_target ? "<@#{event.user.id}>, you were not in the current queue." : "<@#{event.user.id}>, the player #{player.name} was not in AFK mode."
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end

        event.respond(content: message)
      end

      # Team management methods (migrated from TeamCommands)

      def handle_captains(event)
        scrim = Scrim.current_scrims.order(created_at: :desc).first

        if scrim&.captain_a && scrim&.captain_b
          event.respond(content: "<@#{event.user.id}>, the current captains are @#{scrim.captain_a.username} (#{scrim.captain_a.igname}) and @#{scrim.captain_b.username} (#{scrim.captain_b.igname}).")
        else
          event.respond(content: "<@#{event.user.id}>, there are no active scrim captains right now.")
        end
      end

      def handle_roll(event)
        event.respond(content: "<@#{event.user.id}>, you rolled: #{rand(0..100)}")
      end

      def handle_new(event)
        if Scrim.in_progress.exists?
          event.respond(content: "<@#{event.user.id}>, a scrim is already in progress. Finish it with */scrim team win* first, or this will abandon it.")
          return
        end

        queue_count = Player.in_queue.count
        if queue_count != Scrims::FormTeams::QUEUE_SIZE
          event.respond(content: "<@#{event.user.id}>, need exactly #{Scrims::FormTeams::QUEUE_SIZE} players in queue to form teams (currently #{queue_count}).")
          return
        end

        scrim = begin
          Scrims::FormTeams.call!
          ScrimPanelManager.instance.update_all_panels(@bot)
        rescue StandardError => e
          Rails.logger.error("Failed to form new teams: #{e.class}: #{e.message}")
          event.respond(content: "<@#{event.user.id}>, something went wrong forming new teams.")
          return
        end

        event.respond(content: team_roster_message(scrim, :team_a))
        event.channel.send_message(team_roster_message(scrim, :team_b))

        remaining = Player.in_queue.where.not(id: scrim.team_a.players.pluck(:id) + scrim.team_b.players.pluck(:id))
        return unless remaining.any?

        message = 'Next players by order:'
        remaining.each do |player|
          message << "\n<@#{player.uid}>"
          message << ", in-game name **#{player.igname}**" if player.igname.present?
        end
        event.channel.send_message(message)
      end

      def handle_win(event)
        winner = event.options['side'].to_sym

        scrim = begin
          record_win!(winner)
          ScrimPanelManager.instance.update_all_panels(@bot)
        rescue StandardError => e
          Rails.logger.error("Failed to record win: #{e.class}: #{e.message}")
          event.respond(content: "<@#{event.user.id}>, something went wrong recording that result.")
          return
        end

        unless scrim
          event.respond(content: "<@#{event.user.id}>, there is no scrim in progress right now.")
          return
        end

        if scrim.winner_team_id.present?
          winning_label = scrim.winner_team_id == scrim.team_a_id ? 'Team A' : 'Team B'
          event.respond(content: "#{winning_label} wins the series #{scrim.team_a_wins}-#{scrim.team_b_wins}! Elo has been updated.")
        else
          event.respond(content: "Game recorded. Series score: #{scrim.team_a_wins}-#{scrim.team_b_wins}.")
        end
      end

      def handle_move(event)
        server = event.bot.server(ENV['DISCORD_SERVER_ID'])
        channel = event.bot.channel(ENV['DISCORD_SCRIMERS_VOICE_CHANNEL_ID'])

        Registration.current_registrations.order(registered_at: :asc).first(16).each do |registration|
          server.move(event.bot.user(registration.player.uid), channel)
        end
        ScrimPanelManager.instance.update_all_panels(@bot)

        event.respond(content: "<@#{event.user.id}>, the current first 16 players were moved to the Scrimers voice channel.")
      end

      def record_win!(winner)
        Scrim.transaction do
          scrim = Scrim.in_progress.order(created_at: :desc).lock.first
          return nil unless scrim

          Scrims::RecordGameResult.call!(scrim: scrim, winner: winner)
        end
      end

      def team_roster_message(scrim, side)
        team = scrim.public_send(side)
        captain_id = side == :team_a ? scrim.captain_a_id : scrim.captain_b_id
        label = side == :team_a ? 'Team A' : 'Team B'

        message = "#{label}:"
        team.team_players.includes(:player, :profession).each do |team_player|
          player = team_player.player
          message << "\n<@#{player.uid}>"
          message << ', captain' if team_player.player_id == captain_id
          message << ", in-game name **#{player.igname}**" if player.igname.present?
          message << ", #{team_player.profession.name}"
        end
        message
      end

      # Button handlers (migrated from QueueCommands)

      def handle_register_button(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)

        if player.has_current_registration?
          event.respond(content: "You are already registered, #{event.user.username}!", ephemeral: true)
        else
          player.registrations.create(registered_at: DateTime.now)
          form_first_scrim_if_ready!
          
          # Update the panel that the button is on
          panel_manager = ScrimPanelManager.instance
          event.interaction.update_message(has_components: true) do |_, view|
            view.container do |container|
              container.text_display(content: panel_manager.panel_content)
              container.row do |row|
                row.button(label: 'Register', style: :success, custom_id: 'scrim_register')
                row.button(label: 'Unregister', style: :danger, custom_id: 'scrim_unregister')
              end
              container.row do |row|
                row.button(label: 'AFK', style: :secondary, custom_id: 'scrim_afk')
                row.button(label: 'Back (from AFK)', style: :secondary, custom_id: 'scrim_back')
              end
              container.row do |row|
                row.button(label: 'Reset Queue', style: :danger, custom_id: 'scrim_reset')
              end
            end
          end
          
          # Update all panels across all servers
          panel_manager.update_all_panels(@bot)
          
          event.respond(content: "You have been registered, #{event.user.username}!", ephemeral: true)
        end
      end

      def handle_unregister_button(event)
        player = Player.find_by(uid: event.user.id)

        if player&.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          
          # Update the panel that the button is on
          panel_manager = ScrimPanelManager.instance
          event.interaction.update_message(has_components: true) do |_, view|
            view.container do |container|
              container.text_display(content: panel_manager.panel_content)
              container.row do |row|
                row.button(label: 'Register', style: :success, custom_id: 'scrim_register')
                row.button(label: 'Unregister', style: :danger, custom_id: 'scrim_unregister')
              end
              container.row do |row|
                row.button(label: 'AFK', style: :secondary, custom_id: 'scrim_afk')
                row.button(label: 'Back (from AFK)', style: :secondary, custom_id: 'scrim_back')
              end
              container.row do |row|
                row.button(label: 'Reset Queue', style: :danger, custom_id: 'scrim_reset')
              end
            end
          end
          
          # Update all panels across all servers
          panel_manager.update_all_panels(@bot)
          
          event.respond(content: "You have been unregistered, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered, #{event.user.username}!", ephemeral: true)
        end
      end

      def handle_afk_button(event)
        player = Player.find_by(uid: event.user.id)

        message =
          if player&.has_current_registration?
            player.current_registration.update(unregistered_at: DateTime.now)
            ScrimPanelManager.instance.update_all_panels(@bot)
            "<@#{event.user.id}>, you are now in AFK mode."
          elsif player
            "<@#{event.user.id}>, you were not in the current queue."
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end

        event.respond(content: message, ephemeral: true)
      end

      def handle_back_button(event)
        player = Player.find_by(uid: event.user.id)

        message =
          if player&.has_afk_registration?
            player.afk_registration.update(unregistered_at: nil)
            ScrimPanelManager.instance.update_all_panels(@bot)
            "<@#{event.user.id}>, welcome back!"
          elsif player
            "<@#{event.user.id}>, you were not in AFK mode."
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end

        event.respond(content: message, ephemeral: true)
      end

      def handle_reset_button(event)
        Registration.current_registrations.update_all(unregistered_at: DateTime.now)
        ScrimPanelManager.instance.update_all_panels(@bot)
        event.respond(content: "<@#{event.user.id}>, you successfully reset the current queue.")
      end

      # Helper methods (migrated from QueueCommands)

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


    end
  end
end
