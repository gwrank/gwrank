class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.all.order(year: :desc).order(month: :desc)
  end

  def show
    @tournament = Tournament.friendly.find(params[:id])
    render :show_old if @tournament.year.to_i < 2020
  end
end
