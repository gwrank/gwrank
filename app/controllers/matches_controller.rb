class MatchesController < ApplicationController
  def show
    @match = Match.find(params[:id])
    @comment = Comment.new
  end
end
