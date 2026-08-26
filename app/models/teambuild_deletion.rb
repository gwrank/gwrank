# == Schema Information
#
# Table name: teambuild_deletions
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime         not null
#  source_uuid :uuid             not null
#  visibility  :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  player_id   :bigint
#
# Indexes
#
#  index_teambuild_deletions_on_deleted_at                 (deleted_at)
#  index_teambuild_deletions_on_player_id                  (player_id)
#  index_teambuild_deletions_on_player_id_and_source_uuid  (player_id,source_uuid)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id) ON DELETE => nullify
#
class TeambuildDeletion < ApplicationRecord
  belongs_to :player, optional: true

  validates :source_uuid, presence: true
  validates :visibility, inclusion: { in: Teambuild::VISIBILITIES }

  # Same visibility rule that applied to the build before it was deleted:
  # publics for everyone, everything else only for its owner.
  scope :visible_to, ->(player) { where(visibility: "public").or(where(player_id: player)) }
  scope :deleted_since, ->(time) { where(deleted_at: time..) }
end
