module Administration
  class Players::ChecksController < ApplicationController
    def create
      @player = Player.find(params[:player_id])
      @player.update(is_verified: true)
      bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
      bot.user(@player.uid).pm('Congratulations! You are now verified on https://gwrank.com')
      redirect_to administration_players_path
    end
  end
end
