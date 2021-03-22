module Administration
  class TournamentsController < ApplicationController
    def new
      @tournament = Tournament.new
    end

    def create
      @tournament = Tournament.new(tournament_params)
      if @tournament.save
        redirect_to tournament_path(@tournament)
      else
        render :new
      end
    end

    private

    def tournament_params
      params.require(:tournament).permit(:year, :month)
    end
  end
end
