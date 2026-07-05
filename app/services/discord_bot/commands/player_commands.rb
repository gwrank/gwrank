module DiscordBot
  module Commands
    class PlayerCommands
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
        when :register then handle_register(event)
        when :igname then handle_igname(event)
        end
      end

      private

      def register_schema
        @bot.register_application_command(:player, 'Manage your player profile', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:register, 'Set your in-game name') do |sub|
            sub.string(:igname, 'Your in-game character name', required: true)
          end

          cmd.subcommand(:igname, "Look up a player's in-game name") do |sub|
            sub.user(:member, 'The player to look up', required: true)
          end
        end
      end

      def register_dispatch
        handler = @bot.application_command(:player)
        %i[register igname].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end

      def handle_register(event)
        igname = event.options['igname'].to_s.strip
        player = DiscordBot::FindOrCreatePlayer.call(event)
        player.update(igname: igname)

        event.respond(content: "<@#{event.user.id}>, your in-game name is now **#{player.igname}**.")
      end

      def handle_igname(event)
        found_player = Player.find_by(uid: event.options['member'])

        if found_player&.igname.present?
          event.respond(content: "<@#{event.user.id}> (**#{found_player.igname}**)")
        else
          event.respond(content: "<@#{event.user.id}> (in-game name not found)")
        end
      end
    end
  end
end
