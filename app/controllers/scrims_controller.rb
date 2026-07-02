class ScrimsController < ApplicationController
  def index
    @current_registrations = Registration.current_registrations.order(registered_at: :asc)
    @active_scrim = Scrim.in_progress.order(created_at: :desc).first
  end

  def show
    @scrim = Scrim.where.not(team_a_id: nil).find(params[:id])
  end
end
