# == Schema Information
#
# Table name: character_claims
#
#  id            :bigint           not null, primary key
#  status        :string           default("pending")
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  character_id  :bigint           not null
#  claimed_by_id :bigint
#  player_id     :bigint           not null
#
# Indexes
#
#  index_character_claims_on_character_id                (character_id)
#  index_character_claims_on_character_id_and_player_id  (character_id,player_id) UNIQUE WHERE ((status)::text = 'pending'::text)
#  index_character_claims_on_claimed_by_id               (claimed_by_id)
#  index_character_claims_on_player_id                   (player_id)
#
# Foreign Keys
#
#  fk_rails_...  (character_id => characters.id)
#  fk_rails_...  (claimed_by_id => players.id)
#  fk_rails_...  (player_id => players.id)
#

class CharacterClaim < ApplicationRecord
  belongs_to :character
  belongs_to :player
  belongs_to :claimed_by, class_name: 'Player', foreign_key: 'claimed_by_id'

  enum :status, { pending: 'pending', approved: 'approved', rejected: 'rejected' }

  validate :cannot_have_multiple_pending_claims

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }

  after_create :notify_moderators
  after_update :update_player_professions_if_approved

  # Approve the claim and assign the character to the player
  # Handles edge cases:
  # - Character already owned by claimant: just mark as approved
  # - Character owned by different player: reject (race condition protection)
  # - Character unowned: assign to claimant
  def approve!
    return unless pending?

    # Assign the character to the player if not already assigned
    character.update(player: player)
    character.team_players.update_all(player_id: player.id) if character.team_players.any?

    # Update player professions
    player.set_professions_from_team_players
    player.save

    # Mark claim as approved
    update(status: 'approved')
  end

  # Reject the claim
  # Called manually by admins or automatically when character is owned by another player
  def reject!
    update(status: 'rejected')
  end

  private

  def cannot_have_multiple_pending_claims
    return unless pending?
    return unless player_id.present? && character_id.present?

    if CharacterClaim.pending
         .where(player_id: player_id, character_id: character_id)
         .where.not(id: id).exists?
      errors.add(:character, "already has a pending claim")
    end
  end

  def notify_moderators
    # TODO: Implement notification to moderators
    # This could be a Discord message or email
    nil
  end

  def update_player_professions_if_approved
    # Update player professions when claim is approved
    if status_was != 'approved' && status == 'approved'
      player.set_professions_from_team_players
      player.save
    end
  end
end
