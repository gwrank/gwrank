# app/jobs/command_bot_job.rb
class CommandBotJob < ApplicationJob
  queue_as :default

  COMMAND_CLASSES = [
    DiscordBot::Commands::RegistrationCommands,
    DiscordBot::Commands::ProfessionCommands,
    DiscordBot::Commands::TeamCommands,
    DiscordBot::Commands::ClaimCommands,
    DiscordBot::Commands::AtCommands
  ].freeze

  def perform(*args)
    bot = Discordrb::Commands::CommandBot.new(
      token: ENV['DISCORD_BOT_TOKEN'],
      client_id: ENV['DISCORD_CLIENT_ID'],
      prefix: '!'
    )

    COMMAND_CLASSES.each { |command_class| command_class.register(bot) }

    at_exit { bot.stop }
    bot.run
  end
end
