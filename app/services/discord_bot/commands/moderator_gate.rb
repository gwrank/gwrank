module DiscordBot
  module Commands
    module ModeratorGate
      def with_moderator(event)
        player = Player.find_by(uid: event.user.id)
        unless player&.is_moderator?
          event.respond(content: "<@#{event.user.id}>, you need to be a moderator to use this.", ephemeral: true)
          return
        end

        yield
      end
    end
  end
end
