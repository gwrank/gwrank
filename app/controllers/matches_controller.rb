class MatchesController < ApplicationController
  def show
    @match = Match.find(params[:id])
    @comment = Comment.new
    @movie = Movie.new
  end
end
