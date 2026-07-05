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
        end
      end

      private

      def register_schema
        @bot.register_application_command(:team, 'Manage scrim teams and results', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:captains, 'See the current captains')
          cmd.subcommand(:roll, 'Roll 0-100')
        end
      end

      def register_dispatch
        handler = @bot.application_command(:team)
        %i[captains roll].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
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
    end
  end
end
