module DiscordBot
  module Commands
    # Shared by /build and /teambuild: persists the posted build to the
    # author's account and answers ephemerally. Never raises into the
    # caller — the embed has already been posted by then.
    module SaveSupport
      def save_to_account(event, entries, name, visibility: event.options['visibility'])
        player = DiscordBot::FindOrCreatePlayer.call(event)
        result = DiscordBot::SaveBuild.call(
          player: player, entries: Array(entries), name: name,
          visibility: visibility
        )

        unless result.ok?
          detail = result.errors.first&.[]('message')
          content = detail ? "Displayed the build, but couldn't save it: #{detail}"
                           : "Displayed the build, but couldn't save it."
          return event.send_message(content: content, ephemeral: true)
        end

        url = Rails.application.routes.url_helpers.build_url(
          result.teambuild.id, host: ENV.fetch('APP_HOST', 'gwrank.com')
        )
        verb = result.created? ? 'saved to' : 'updated in'
        event.send_message(
          content: "Build #{verb} your account as **#{result.teambuild.visibility}**.\n[View build](#{url})",
          ephemeral: true
        )
      rescue StandardError => e
        Rails.logger.error("Failed to save build from Discord: #{e.class}: #{e.message}")
        begin
          event.send_message(content: "Displayed the build, but couldn't save it right now.", ephemeral: true)
        rescue StandardError
          nil
        end
      end
    end
  end
end
