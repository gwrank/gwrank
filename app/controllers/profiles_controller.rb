class ProfilesController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:edit, :update, :destroy]

  def edit
    @guilds = Guild.active.order(name: :asc)
    @character = Character.new
    @professions = Profession.all
  end

  def update
    if @player.igname != player_params[:igname] && !player_params[:igname].empty?
      if @player.is_verified?
        @player.update(is_verified: false)
      end
      character_igname = player_params[:igname].strip.titleize
      # Use find_by_igname for hashed lookups, or create if not exists
      character = Character.find_by_igname(character_igname)
      if character.nil?
        character = Character.new(igname: character_igname)
        character.save
      end
      character.update(player: @player) unless character.player.present?
      TeamPlayer.where(igname: character_igname).update_all(player_id: @player.id)
    end

    if @player.update(player_params)
      redirect_to player_path(@player)
    else
      @guilds = Guild.active.order(name: :asc)
      render :edit
    end
  end

  def destroy
    @player.destroy
    redirect_to root_path
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
