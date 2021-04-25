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
      character_igname = player_params[:igname].strip.titleize
      character = Character.where(igname: character_igname).first_or_create
      character.update(player: @player) unless character.player.present?
      @player.team_players.update_all(player_id: Player.find_by(email: 'default@gwrank.com').id)
      TeamPlayer.where(igname: character_igname).update_all(player_id: @player.id)
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
