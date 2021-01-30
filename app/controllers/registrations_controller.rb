class RegistrationsController < ApplicationController
  before_action :authenticate_player!

  def create
    current_player.registrations.create(registered_at: DateTime.now)

    if Registration.current_registrations.count.eql?(16)
      captain_a = Registration.current_registrations.shuffle.first.player
      captain_b = Registration.current_registrations.where.not(id: captain_a.current_registration.id).shuffle.first.player
      Scrim.create!(
        captain_a: captain_a,
        captain_b: captain_b,
      )
    end

    redirect_to scrims_path
  end

  def destroy
    registration = current_player.registrations.find(params[:id])
    registration.update(unregistered_at: DateTime.now)
    redirect_to scrims_path
  end
end
