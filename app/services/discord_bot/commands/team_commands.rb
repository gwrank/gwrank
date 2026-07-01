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
        @bot.command(:captains, description: 'to see the current captains') do |event|
          handle_captains_command(event)
        end

        @bot.command(:roll, description: 'to roll 100') do |event|
          handle_roll_command(event)
        end

        @bot.command(:newteams, description: 'to form new teams for the next series (moderators only)') do |event|
          player = Player.find_by(uid: event.user.id)
          handle_newteams_command(event) if player&.is_moderator?
        end

        @bot.command(:win, description: 'to record a game win for team a or b (moderators only)') do |event, team|
          player = Player.find_by(uid: event.user.id)
          handle_win_command(event, team) if player&.is_moderator?
        end

        @bot.command(:moveplayers, description: 'to automatically move players to the Scrimers voice channel (moderators only)') do |event|
          handle_moveplayers_command(event)
        end
      end

      private

      def handle_captains_command(event)
        scrim = Scrim.current_scrims.order(created_at: :desc).first

        if scrim&.captain_a && scrim&.captain_b
          event.respond "<@#{event.user.id}>, the current captains are @#{scrim.captain_a.username} (#{scrim.captain_a.igname}) and @#{scrim.captain_b.username} (#{scrim.captain_b.igname})."
        else
          event.respond "<@#{event.user.id}>, there are no active scrim captains right now."
        end
      end

      def handle_roll_command(event)
        event.respond "<@#{event.user.id}>, you rolled: #{rand(0..100)}"
      end

      def handle_newteams_command(event)
        if Scrim.in_progress.exists?
          event.respond "<@#{event.user.id}>, a scrim is already in progress. Finish it with *!win* first, or this will abandon it."
          return
        end

        scrim = Scrims::FormTeams.call!

        event.channel.send_message(team_roster_message(scrim, :team_a))
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

      def handle_win_command(event, team)
        winner = { 'a' => :a, 'b' => :b }[team.to_s.downcase]
        unless winner
          event.respond "<@#{event.user.id}>, usage: *!win a* or *!win b*"
          return
        end

        scrim = record_win!(winner)

        unless scrim
          event.respond "<@#{event.user.id}>, there is no scrim in progress right now."
          return
        end

        if scrim.winner_team_id.present?
          winning_label = scrim.winner_team_id == scrim.team_a_id ? 'Team A' : 'Team B'
          event.channel.send_message "#{winning_label} wins the series #{scrim.team_a_wins}-#{scrim.team_b_wins}! Elo has been updated."
        else
          event.channel.send_message "Game recorded. Series score: #{scrim.team_a_wins}-#{scrim.team_b_wins}."
        end
      rescue StandardError => e
        Rails.logger.error("Failed to record win: #{e.class}: #{e.message}")
        event.respond "<@#{event.user.id}>, something went wrong recording that result."
      end

      def record_win!(winner)
        Scrim.transaction do
          scrim = Scrim.in_progress.order(created_at: :desc).lock.first
          return nil unless scrim

          Scrims::RecordGameResult.call!(scrim: scrim, winner: winner)
        end
      end

      def handle_moveplayers_command(event)
        player = Player.find_by(uid: event.user.id)
        unless player&.is_moderator?
          event.respond "<@#{event.user.id}>, you need to ask a moderator to move players."
          return
        end

        server = event.bot.server(ENV['DISCORD_SERVER_ID'])
        channel = event.bot.channel(ENV['DISCORD_SCRIMERS_VOICE_CHANNEL_ID'])

        Registration.current_registrations.order(registered_at: :asc).first(16).each do |registration|
          server.move(event.bot.user(registration.player.uid), channel)
        end

        event.respond "<@#{event.user.id}>, the current first 16 players were moved to the Scrimers voice channel."
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
