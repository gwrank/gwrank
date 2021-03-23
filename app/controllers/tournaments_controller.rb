class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.all.order(year: :desc).order(month: :desc)
  end

  def show
    @tournament = Tournament.friendly.find(params[:id])
  end
end
