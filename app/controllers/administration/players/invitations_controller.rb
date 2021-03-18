module Administration
  class Players::InvitationsController < ApplicationController
    def create
      @player = Player.friendly.find(params[:player_id])
      bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
      bot.user(@player.uid).pm('Hello! Are you free for scrim? !register in #scrims channel of GWRank.com Discord. Here is a direct link to the channel: https://discord.com/channels/788820055029973045/806189775308193802')
      redirect_to administration_players_path
    end
  end
end
