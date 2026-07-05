# app/services/discord_bot/commands/team_commands.rb
module DiscordBot
  module Commands
    class TeamCommands
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
        end
      end

      private

      def register_schema
        @bot.register_application_command(:team, 'Manage scrim teams and results', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:captains, 'See the current captains')
          cmd.subcommand(:roll, 'Roll 0-100')
          cmd.subcommand(:new, 'Form new teams for the next series (moderators only)')
        end
      end

      def register_dispatch
        handler = @bot.application_command(:team)
        %i[captains roll new].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end

      def with_moderator(event)
        player = Player.find_by(uid: event.user.id)
        unless player&.is_moderator?
          event.respond(content: "<@#{event.user.id}>, you need to be a moderator to use this.", ephemeral: true)
          return
        end

        yield
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
