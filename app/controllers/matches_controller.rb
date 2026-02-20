class MatchesController < ApplicationController
  before_action :authenticate_player!, only: [:new, :create]

  def index
    @pagy, @matches = pagy(Match.order(played_at: :desc))
  end

  def show
    @match = Match.find(params[:id])
    @comment = Comment.new
    @movie = Movie.new

    respond_to do |format|
      format.html
      format.json { render json: @match.json }
    end
  end

  def new
    @match = Match.new
  end

  def create
    @match = Match.import!(match_params)

    message = "New match! #{match.title} : #{match_url(match)}"
    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
    bot.channel(ENV['DISCORD_COMMAND_CHANNEL_ID']).send_message(message)

    redirect_to match_path(@match)
  end

  private

  def match_params
    params.require(:match).permit(:json_file).merge(imported_by: current_player, imported_at: Time.zone.now)
  end
end
