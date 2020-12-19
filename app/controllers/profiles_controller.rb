class ProfilesController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:edit, :update]

  def edit
  end

  def update
    if @player.is_verified? && @player.igname != player_params[:igname]
      @player.update(is_verified: false)
    end

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
    params.require(:player).permit(
      :igname,
      :is_warrior,
      :is_ranger,
      :is_monk,
      :is_necromancer,
      :is_mesmer,
      :is_elementalist,
      :is_assassin,
      :is_ritualist,
      :is_paragon,
      :is_dervish
    )
  end
end
