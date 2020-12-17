class ProfilesController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:edit, :update]

  def edit
  end

  def update
    if @player.update(player_params)
      redirect_to root_path
    else
      render :edit
    end
  end

  private

  def set_player
    @player = current_player
  end

  def player_params
    params.require(:player).permit(:igname)
  end
end
