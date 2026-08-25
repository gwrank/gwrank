# == Schema Information
#
# Table name: teambuilds
#
#  id            :bigint           not null, primary key
#  document      :jsonb            not null
#  document_hash :string
#  game_mode     :string           default("")
#  name          :string
#  player_count  :integer
#  source_uuid   :uuid             not null
#  status        :string           default("published"), not null
#  tags          :string           default([]), is an Array
#  visibility    :string           default("private"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  player_id     :bigint           not null
#
# Indexes
#
#  index_teambuilds_on_player_count               (player_count)
#  index_teambuilds_on_player_id                  (player_id)
#  index_teambuilds_on_player_id_and_source_uuid  (player_id,source_uuid) UNIQUE
#  index_teambuilds_on_status                     (status)
#  index_teambuilds_on_tags                       (tags) USING gin
#  index_teambuilds_on_updated_at                 (updated_at)
#  index_teambuilds_on_visibility                 (visibility)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id)
#
class Teambuild < ApplicationRecord
  VISIBILITIES = %w[private public].freeze
  STATUSES = %w[draft published].freeze
  SORTS = {
    "updated_at" => { updated_at: :desc },
    "name" => { name: :asc },
    "player_count" => { player_count: :desc }
  }.freeze

  belongs_to :player
  has_many :teambuild_characters, -> { order(:position) }, inverse_of: :teambuild, dependent: :destroy

  validates :source_uuid, presence: true, uniqueness: { scope: :player_id }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :player_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 12 }, allow_nil: true

  scope :publicly_visible, -> { where(visibility: "public") }
  scope :owned_by, ->(player) { where(player_id: player) }
  scope :visible_to, ->(player) { publicly_visible.or(owned_by(player)) }
  scope :draft, -> { where(status: "draft") }
  scope :published, -> { where(status: "published") }
  scope :with_status, ->(value) { where(status: value) }
  scope :with_name_like, ->(query) { where("name ILIKE ?", "%#{sanitize_sql_like(query)}%") }
  scope :tagged_with_any, ->(values) { where("tags && ARRAY[?]::varchar[]", Array(values)) }
  scope :with_primary_profession, ->(id) { joins(:teambuild_characters).where(teambuild_characters: { primary_profession_id: id }).distinct }
  scope :with_elite_skill, ->(id) { joins(:teambuild_characters).where(teambuild_characters: { elite_skill_id: id }).distinct }
  scope :with_profession_code, ->(code) do
    profession = Profession.find_by(profession_id: code)
    profession ? with_primary_profession(profession.id) : none
  end
  scope :with_skill_id, ->(gw1_skill_id) do
    skill = Skill.find_by(skill_id: gw1_skill_id)
    skill ? with_elite_skill(skill.id) : none
  end
  scope :with_campaign, ->(name) { joins(teambuild_characters: :elite_skill).where(skills: { campaign: name }).distinct }
  scope :with_game_mode, ->(mode) { where(game_mode: mode) }
  scope :with_updated_since, ->(time) { where(updated_at: time..) }

  def visible_to?(player)
    visibility == "public" || player_id == player&.id
  end

  def summary
    {
      id: id,
      sourceId: source_uuid,
      name: name,
      author: player&.username,
      tags: tags,
      gameMode: game_mode,
      playerCount: player_count,
      visibility: visibility,
      status: status,
      characters: teambuild_characters.map(&:summary),
      createdAt: created_at,
      updatedAt: updated_at,
      documentHash: document_hash
    }
  end

  def export_summary
    summary.merge(document: document)
  end
end
