class TournamentsController < ApplicationController
  def index
    @tournaments = Tournament.order(date: :desc, year: :desc, month: :desc)
    
    # Apply filters
    @tournaments = @tournaments.where("date >= ?", params[:date_from].to_date.beginning_of_day) if params[:date_from].present?
    @tournaments = @tournaments.where("date <= ?", params[:date_to].to_date.end_of_day) if params[:date_to].present?
    
    # Tournament type filter
    if params[:tournament_type].present?
      @tournaments = @tournaments.where(tournament_type: params[:tournament_type])
      # Region filter only applies to AT tournaments
      if params[:tournament_type] == 'at' && params[:tournament_region].present?
        @tournaments = @tournaments.where(region: params[:tournament_region])
      end
    end
    
    # Flux filter (month-based)
    if params[:flux_year].present? && params[:flux_month].present?
      year = params[:flux_year].to_i
      month = params[:flux_month].to_i
      flux_date = Date.new(year, month, 1)
      @tournaments = @tournaments.where("date >= ? AND date <= ?", 
                                       flux_date.beginning_of_month.beginning_of_day,
                                       flux_date.end_of_month.end_of_day)
    end
    
    @pagy, @tournaments = pagy(@tournaments)
  end

  def show
    @tournament = Tournament.friendly.find(params[:id])
    @comment = Comment.new
    render :show_old if @tournament.year.to_i < 2020
  end
end
