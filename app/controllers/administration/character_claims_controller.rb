class Administration::CharacterClaimsController < ApplicationController
  before_action :authenticate_player!
  before_action :authorize_moderator!
  before_action :set_claim, only: [:show, :approve, :reject]

  def index
    @claims = CharacterClaim.pending.includes(:character, :player, :claimed_by).order(created_at: :desc)
  end

  def show
    # Already set by set_claim
  end

  def approve
    @claim.approve!
    flash[:notice] = "Character claim for '#{@claim.character.igname}' has been approved."
    redirect_to administration_character_claims_path
  end

  def reject
    @claim.reject!
    flash[:notice] = "Character claim for '#{@claim.character.igname}' has been rejected."
    redirect_to administration_character_claims_path
  end

  private

  def set_claim
    @claim = CharacterClaim.find(params[:id])
  end

  def authorize_moderator!
    unless current_player.is_moderator?
      flash[:alert] = "You are not authorized to access this page."
      redirect_to root_path
    end
  end
end
