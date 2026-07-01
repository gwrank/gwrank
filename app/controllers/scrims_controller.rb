class ScrimsController < ApplicationController
  def index
    @current_registrations = Registration.current_registrations.order(registered_at: :asc)
    @current_scrims = Scrim.current_scrims
  end
end
