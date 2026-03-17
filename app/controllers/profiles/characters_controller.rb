class Profiles::CharactersController < ApplicationController
  before_action :authenticate_player!
  before_action :set_player, only: [:new, :create]
  before_action :set_character, only: [:destroy]

  def new
    @character = Character.new
    @professions = Profession.all
  end

  def create
    character_igname = character_params[:igname].strip.titleize
    # Use find_by_igname for hashed lookups
    @character = Character.find_by_igname(character_igname)
    if @player.is_verified?
      @player.update(is_verified: false)
    end
    if @character.present?
      if @character.claimable_by?(@player)
        # Character is unowned or owned by this player - claim it directly
        @character.update(player_id: @player.id)
        TeamPlayer.where(igname: character_igname).update_all(
          character_id: @character.id,
          player_id: @player.id
        )
        @player.set_professions_from_team_players
        @player.save
        flash[:notice] = "Character '#{@character.igname}' has been added to your profile."
        redirect_to edit_profile_path
      else
        # Character is owned by another player - create a claim for verification
        existing_claim = CharacterClaim.find_by(character: @character, player: @player, status: 'pending')
        if existing_claim
          flash[:alert] = "You already have a pending claim for character '#{@character.igname}'. A moderator will review it shortly."
        else
          CharacterClaim.create!(
            character: @character,
            player: @player,
            claimed_by: @player,
            status: 'pending'
          )
          flash[:notice] = "Your claim for character '#{@character.igname}' has been submitted for moderator verification. " \
                           "Once approved, the character will be linked to your profile."
        end
        redirect_to edit_profile_path
      end
    else
      @character = Character.new(character_params)
      @character.igname = character_igname
      @character.player = @player
      if @character.save
        TeamPlayer.where(igname: character_igname).update_all(
          character_id: @character.id,
          player_id: @player.id
        )
        @player.set_professions_from_team_players
        @player.save
        flash[:notice] = "Character '#{@character.igname}' has been added to your profile."
        redirect_to edit_profile_path
      else
        @professions = Profession.all
        render :new
      end
    end
  end

  def destroy
    @character.unlink!
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
