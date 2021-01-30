class ProfilesController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:edit, :update]

  def edit
    @guilds = Guild.all
  end

  def update
    if @player.is_verified? && @player.igname != player_params[:igname]
      @player.update(is_verified: false)
    end

    if @player.update(player_params)
      redirect_to player_path(@player)
    else
      @guilds = Guild.all
      render :edit
    end
  end

  private

  def set_player
    @player = current_player
  end

  def player_params
    params.require(:player).permit(
      :guild_id,
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
      :is_dervish,
      :twitch_username,
    )
  end
end
