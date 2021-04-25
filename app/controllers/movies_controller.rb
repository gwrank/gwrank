class MoviesController < ApplicationController
  before_action :authenticate_player!

  def create
    @movie = Movie.new(movie_params)
    @movie.player = current_player
    @movie.save

    case movie_params['movieable_type']
    when 'Match'
      match = Match.find(movie_params['movieable_id'])
      url = match_url(match)
      message = "New video on the match #{match.title} : #{url}"
    end
    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
    bot.channel(ENV['DISCORD_COMMAND_CHANNEL_ID']).send_message(message)

    redirect_back fallback_location: root_path
  end

  private

  def movie_params
    params.require(:movie).permit(:movieable_type, :movieable_id, :provider, :video_url)
  end
end
