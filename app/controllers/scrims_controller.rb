class ScrimsController < ApplicationController
  before_action :authenticate_player!

  def index
    @current_registrations = Registration.current_registrations.order(registered_at: :asc)
    @current_scrims = Scrim.current_scrims
  end
end
