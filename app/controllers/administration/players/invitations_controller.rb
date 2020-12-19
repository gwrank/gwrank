module Administration
  class Players::InvitationsController < ApplicationController
    def create
      @player = Player.find(params[:player_id])
      bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
      bot.user(@player.uid).pm('Hello! Are you free for scrim? Register on https://gwrank.com')
      redirect_to administration_players_path
    end
  end
end
