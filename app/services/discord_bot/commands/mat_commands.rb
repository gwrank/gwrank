# app/services/discord_bot/commands/mat_commands.rb

module DiscordBot
  module Commands
    class MatCommands
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
        
        @bot.button(custom_id: 'mat_register') do |event|
          handle_mat_register_button(event)
        end
        
        @bot.button(custom_id: 'mat_unregister') do |event|
          handle_mat_unregister_button(event)
        end
      end
      
      def register_schema
        @bot.register_application_command(:mat, 'Manage Monthly Automated Tournament queue', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:schedule, 'Set the monthly AT schedule pattern') do |sub|
            sub.string(:pattern, 'Monthly pattern', required: true, 
                       choices: { 'Every 3rd Saturday' => 'every_3rd_saturday' })
          end
          
          cmd.subcommand(:next, 'Show time until the next monthly AT')
          cmd.subcommand(:join, 'Post the Monthly AT registration panel')
          cmd.subcommand(:players, 'List players in the monthly AT queue')
        end
      end
      
      def register_dispatch
        handler = @bot.application_command(:mat)
        %i[schedule next join players].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
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
      
      def handle_schedule(event)
        discord_server_id = event.server.id
        pattern = event.options['pattern']
        
        schedule = AutomatedTournamentSchedule.find_or_initialize_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        schedule.recurrence_pattern = pattern
        schedule.channel_id = event.channel.id
        schedule.registration_opens_days_before = 28
        schedule.save!
        
        next_occ = schedule.next_occurrence
        event.respond(content: "<@#{event.user.id}>, this server now tracks monthly AT with pattern **#{pattern}**; reminders will post in this channel. Next monthly AT: #{next_occ.strftime('%Y-%m-%d %H:%M UTC')}.")
      end
      
      def handle_next(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "<@#{event.user.id}>, this server hasn't set a monthly AT schedule yet. Run */mat schedule* first.") unless schedule
        
        now = Time.now.utc
        next_occ = schedule.next_occurrence(from: now)
        
        message = if next_occ > now
          registration_start = next_occ - schedule.registration_opens_days_before.days
          if now >= registration_start
            "<@#{event.user.id}>, the next monthly AT starts in #{format_duration(next_occ - now)} (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')}). Registration is OPEN!"
          else
            "<@#{event.user.id}>, the next monthly AT starts in #{format_duration(next_occ - now)} (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')}). Registration opens in #{format_duration(registration_start - now)}."
          end
        else
          "<@#{event.user.id}>, the monthly AT started #{format_duration(now - next_occ)} ago."
        end
        
        event.respond(content: message)
      end
      
      def handle_join(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "<@#{event.user.id}>, this server hasn't set a monthly AT schedule yet. Run */mat schedule* first.") unless schedule
        
        player = DiscordBot::FindOrCreatePlayer.call(event)
        
        event.respond(has_components: true) do |_, view|
          mat_container(view, player, discord_server_id: discord_server_id)
        end
      end
      
      def handle_players(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "<@#{event.user.id}>, this server hasn't set a monthly AT schedule yet. Run */mat schedule* first.") unless schedule
        
        mat_registrations = AutomatedTournamentRegistration.current_monthly_for_server(discord_server_id).order(registered_at: :asc)
        
        message = "<@#{event.user.id}>, the current monthly AT queue players for this server are:"
        if mat_registrations.empty?
          message << "\nNo players in the queue yet."
        else
          mat_registrations.each_with_index do |registration, index|
            message << "\n##{index + 1} <@#{registration.player.uid}>"
            message << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          end
        end
        
        mat_count = mat_registrations.count
        message << (mat_count < QUEUE_SIZE ? "\nWe need #{QUEUE_SIZE - mat_count} more players." : "\nTeam is full! (#{QUEUE_SIZE} players)")
        
        event.respond(content: message)
      end
      
      def handle_mat_register_button(event)
        discord_server_id = event.server_id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "This server hasn't set a monthly AT schedule yet.", ephemeral: true) unless schedule
        
        player = DiscordBot::FindOrCreatePlayer.call(event)
        
        if player.has_current_mat_registration?(discord_server_id)
          event.respond(content: "You are already registered in the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
          return
        end
        
        AutomatedTournamentRegistration.create!(
          player: player, 
          discord_server_id: discord_server_id, 
          registered_at: DateTime.now,
          is_monthly: true
        )
        mat_count = AutomatedTournamentRegistration.current_monthly_for_server(discord_server_id).count
        
        event.interaction.update_message(has_components: true) do |_, view|
          mat_container(view, player, discord_server_id: discord_server_id)
        end
        event.send_message(content: "You have been registered in the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
        
        if mat_count == QUEUE_SIZE
          event.channel.send_message "Team is full! #{QUEUE_SIZE} players registered for the Monthly Automated Tournament."
        elsif mat_count > QUEUE_SIZE
          event.channel.send_message "Monthly AT queue now has #{mat_count} players for this server."
        end
      end
      
      def handle_mat_unregister_button(event)
        discord_server_id = event.server_id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "This server hasn't set a monthly AT schedule yet.", ephemeral: true) unless schedule
        
        player = Player.find_by(uid: event.user.id)
        
        if player&.has_current_mat_registration?(discord_server_id)
          player.current_mat_registration(discord_server_id).update(unregistered_at: DateTime.now)
          event.interaction.update_message(has_components: true) do |_, view|
            mat_container(view, player, discord_server_id: discord_server_id)
          end
          event.send_message(content: "You have been unregistered from the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered in the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
        end
      end
      
      def mat_container(view, player, discord_server_id: nil)
        view.container do |container|
          container.text_display(content: mat_registration_panel_content(player, discord_server_id: discord_server_id))
          container.row do |row|
            row.button(label: 'Register', style: :success, custom_id: 'mat_register')
            row.button(label: 'Unregister', style: :danger, custom_id: 'mat_unregister')
          end
        end
      end
      
      def mat_registration_panel_content(player, discord_server_id: nil)
        mat_registrations = AutomatedTournamentRegistration.current_monthly_for_server(discord_server_id).order(registered_at: :asc)
        
        players = mat_registrations.each_with_index.map do |registration, index|
          entry = "\n##{index + 1} <@#{registration.player.uid}>"
          entry << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          entry
        end
        
        message = "### Monthly Automated Tournament Registration Panel\n"
        message << "Current registered players for this server:\n"
        message << (players.empty? ? "No players registered yet.\n" : players.join("\n"))
        message << "\n"
        
        mat_count = mat_registrations.count
        message << (mat_count < QUEUE_SIZE ? "We need #{QUEUE_SIZE - mat_count} more players." : "Team is full! (#{QUEUE_SIZE} players)")
        message
      end
      
      def format_duration(seconds)
        total_minutes = (seconds / 60).round
        hours, minutes = total_minutes.divmod(60)
        hours.positive? ? "#{hours}h #{minutes}m" : "#{minutes}m"
      end
    end
  end
end
