class RegistrationsController < ApplicationController
  before_action :authenticate_player!

  def create
    if current_player.has_current_registration?
      message = "<@#{current_player.uid}>, you are already in the current queue."
    else
      current_player.registrations.create(registered_at: DateTime.now)
      current_registrations = Registration.current_registrations
      message = "<@#{current_player.uid}>, you are number #{current_registrations.count} in the current queue for the next 8 hours."
      message << "\nIf you're out, please type *!unregister*"

      if current_registrations.count < 16
        players_required = 16 - current_registrations.count
        message << "\nWe need #{players_required} more players."
      elsif current_registrations.count.eql?(16)
        message << "\nWe have 16 players!"
        message << "\nTo see the players list, you can type *!players* or go on https://gwrank.com/scrims"
        message << "\nTo roll 100, captains can type *!roll*"
        message << "\nTo automatically designate captains, you can type *!newcaptains*"
      end
    end

    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
    bot.channel(ENV['DISCORD_COMMAND_CHANNEL_ID']).send_message(message)

    redirect_to scrims_path
  end

  def destroy
    if current_player.has_current_registration?
      current_player.current_registration.update(unregistered_at: DateTime.now)
      message = "<@#{current_player.uid}>, you are not anymore in the current queue."
    else
      message = "<@#{current_player.uid}>, you were not in the current queue."
    end

    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
    bot.channel(ENV['DISCORD_COMMAND_CHANNEL_ID']).send_message(message)

    redirect_to scrims_path
  end
end
