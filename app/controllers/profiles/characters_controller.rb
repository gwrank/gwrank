class Profiles::CharactersController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:new, :create]
  before_action :set_character, only: [:edit, :update, :destroy]

  def new
    @character = Character.new
    @professions = Profession.all
  end

  def create
    character_igname = character_params[:igname].strip.titleize
    @character = Character.find_by(igname: character_igname)
    if @player.is_verified?
      @player.update(is_verified: false)
    end
    if @character.present?
      if @character.player_id.present?
        @professions = Profession.all
        render :new
      else
        @character.update(player_id: @player.id)
        TeamPlayer.where(igname: @character.igname).update_all(
          character_id: @character.id,
          player_id: @player.id
        )
        redirect_to edit_profile_path
      end
    else
      @character = Character.new(character_params)
      @character.igname = character_igname
      @character.player = @player
      if @character.save
        TeamPlayer.where(igname: @character.igname).update_all(
          character_id: @character.id,
          player_id: @player.id
        )
        redirect_to edit_profile_path
      else
        @professions = Profession.all
        render :new
      end
    end
  end

  def destroy
    @character.destroy
    redirect_to edit_profile_path
  end

  private

  def set_player
    @player = current_player
  end

  def set_professions
    @professions = Profession.all
  end

  def set_character
    @character = current_player.characters.find(params[:id])
  end

  def character_params
    params.require(:character).permit(:igname, :profession_id)
  end
end
