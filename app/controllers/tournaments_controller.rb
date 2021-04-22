class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.monthly.order(year: :desc).order(month: :desc)
  end

  def show
    @tournament = Tournament.friendly.find(params[:id])
    @comment = Comment.new
    render :show_old if @tournament.year.to_i < 2020
  end
end
