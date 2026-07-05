# app/services/discord_bot/commands/team_commands.rb
module DiscordBot
  module Commands
    class TeamCommands
      include ModeratorGate

      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        register_schema
        register_dispatch
      end

      def dispatch(event)
        case event.subcommand
        when :captains then handle_captains(event)
        when :roll then handle_roll(event)
        when :new then with_moderator(event) { handle_new(event) }
        when :win then with_moderator(event) { handle_win(event) }
        when :move then with_moderator(event) { handle_move(event) }
        end
      end

      private

      def register_schema
        @bot.register_application_command(:team, 'Manage scrim teams and results', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:captains, 'See the current captains')
          cmd.subcommand(:roll, 'Roll 0-100')
          cmd.subcommand(:new, 'Form new teams for the next series (moderators only)')
          cmd.subcommand(:win, 'Record a game win for a team (moderators only)') do |sub|
            sub.string(:side, 'Which team won', required: true, choices: { 'Team A' => 'a', 'Team B' => 'b' })
          end
          cmd.subcommand(:move, 'Move the current queue to the Scrimers voice channel (moderators only)')
        end
      end

      def register_dispatch
        handler = @bot.application_command(:team)
        %i[captains roll new win move].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end

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
          event.respond(content: "<@#{event.user.id}>, a scrim is already in progress. Finish it with */team win* first, or this will abandon it.")
          return
        end

        queue_count = Player.in_queue.count
        if queue_count != Scrims::FormTeams::QUEUE_SIZE
          event.respond(content: "<@#{event.user.id}>, need exactly #{Scrims::FormTeams::QUEUE_SIZE} players in queue to form teams (currently #{queue_count}).")
          return
        end

        scrim = begin
          Scrims::FormTeams.call!
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
    end
  end
end
