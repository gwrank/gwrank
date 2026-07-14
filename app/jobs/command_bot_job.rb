# app/jobs/command_bot_job.rb
class CommandBotJob < ApplicationJob
  queue_as :default

  COMMAND_CLASSES = [
    DiscordBot::Commands::PlayerCommands,
    DiscordBot::Commands::QueueCommands,
    DiscordBot::Commands::TeamCommands,
    DiscordBot::Commands::AtCommands,
    DiscordBot::Commands::BuildCommands
  ].freeze

  def perform(*args)
    bot = Discordrb::Commands::CommandBot.new(
      token: ENV['DISCORD_BOT_TOKEN'],
      client_id: ENV['DISCORD_CLIENT_ID']
    )

    COMMAND_CLASSES.each { |command_class| command_class.register(bot) }

    at_exit { bot.stop }
    bot.run
  end
end
