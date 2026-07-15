# app/jobs/command_bot_job.rb
class CommandBotJob < ApplicationJob
  queue_as :default

  COMMAND_CLASSES = [
    DiscordBot::Commands::PlayerCommands,
    DiscordBot::Commands::QueueCommands,
    DiscordBot::Commands::TeamCommands,
    DiscordBot::Commands::AtCommands,
    DiscordBot::Commands::BuildCommands,
    DiscordBot::Commands::TeamBuildCommands
  ].freeze

  REMINDER_POLL_INTERVAL = 15.minutes

  def perform(*args)
    bot = Discordrb::Commands::CommandBot.new(
      token: ENV['DISCORD_BOT_TOKEN'],
      client_id: ENV['DISCORD_CLIENT_ID']
    )

    COMMAND_CLASSES.each { |command_class| command_class.register(bot) }

    start_at_reminder_thread(bot)

    at_exit { bot.stop }
    bot.run
  end

  private

  def start_at_reminder_thread(bot)
    Thread.new do
      loop do
        DiscordBot::AtReminderCheck.call(bot: bot)
        sleep(REMINDER_POLL_INTERVAL)
      rescue StandardError => e
        Rails.logger.error("AT reminder poll loop error: #{e.class}: #{e.message}")
      end
    end
  end
end
