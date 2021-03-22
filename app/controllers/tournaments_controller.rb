class TournamentsController < ApplicationController
  before_action :authenticate_player!

  def index
    @tournaments = Tournament.all.order(year: :desc).order(month: :desc)
  end

  def show
    @tournament = Tournament.friendly.find(params[:id])
  end
end
