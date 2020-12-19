class RegistrationsController < ApplicationController
  before_action :authenticate_player!

  def create
    current_player.registrations.create(registered_at: DateTime.now)
    redirect_to root_path
  end

  def destroy
    registration = current_player.registrations.find(params[:id])
    registration.update(unregistered_at: DateTime.now)
    redirect_to root_path
  end
end
