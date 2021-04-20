class ProfilesController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:edit, :update]

  def edit
    @guilds = Guild.active.order(name: :asc)
  end

  def update
    if @player.igname != player_params[:igname]
      if @player.is_verified?
        @player.update(is_verified: false)
      end
      @player.team_players.update_all(player_id: Player.find_by(igname: 'Gwrank Com').id)
      TeamPlayer.where(igname: player_params[:igname]).update_all(player_id: @player.id)
    end

    if @player.update(player_params)
      redirect_to player_path(@player)
    else
      @guilds = Guild.active.order(name: :asc)
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
