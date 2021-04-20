class CommentsController < ApplicationController
  before_action :authenticate_player!

  def create
    @comment = Comment.new(comment_params)
    @comment.player = current_player
    @comment.save

    case comment_params['commentable_type']
    when 'Match'
      match = Match.find(comment_params['commentable_id'])
      url = match_url(match)
      message = "New comment on the match #{match.title} : #{url}"
    when 'Tournament'
      tournament = Tournament.find(comment_params['commentable_id'])
      url = tournament_url(tournament)
      message = "New comment on the tournament #{tournament.title} : #{url}"
    end
    bot = Discordrb::Bot.new token: ENV['DISCORD_BOT_TOKEN']
    bot.channel(ENV['DISCORD_COMMAND_CHANNEL_ID']).send_message(message)

    redirect_back fallback_location: root_path
  end

  private

  def comment_params
    params.require(:comment).permit(:commentable_type, :commentable_id, :body)
  end
end
