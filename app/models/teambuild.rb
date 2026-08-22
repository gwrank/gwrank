class Teambuild < ApplicationRecord
  VISIBILITIES = %w[private public].freeze
  SORTS = {
    "updated_at" => { updated_at: :desc },
    "name" => { name: :asc },
    "player_count" => { player_count: :desc }
  }.freeze

  belongs_to :player
  has_many :teambuild_characters, -> { order(:position) }, inverse_of: :teambuild, dependent: :destroy

  validates :source_uuid, presence: true, uniqueness: { scope: :player_id }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :player_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 12 }, allow_nil: true

  scope :publicly_visible, -> { where(visibility: "public") }
  scope :owned_by, ->(player) { where(player_id: player) }
  scope :visible_to, ->(player) { publicly_visible.or(owned_by(player)) }
  scope :with_name_like, ->(query) { where("name ILIKE ?", "%#{sanitize_sql_like(query)}%") }
  scope :tagged_with_any, ->(values) { where("tags && ARRAY[?]::varchar[]", Array(values)) }
  scope :with_primary_profession, ->(id) { joins(:teambuild_characters).where(teambuild_characters: { primary_profession_id: id }).distinct }
  scope :with_elite_skill, ->(id) { joins(:teambuild_characters).where(teambuild_characters: { elite_skill_id: id }).distinct }
  scope :with_campaign, ->(name) { joins(teambuild_characters: :elite_skill).where(skills: { campaign: name }).distinct }
  scope :with_game_mode, ->(mode) { where(game_mode: mode) }

  def visible_to?(player)
    visibility == "public" || player_id == player&.id
  end

  def summary
    {
      id: id,
      sourceId: source_uuid,
      name: name,
      tags: tags,
      gameMode: game_mode,
      playerCount: player_count,
      visibility: visibility,
      characters: teambuild_characters.map(&:summary),
      createdAt: created_at,
      updatedAt: updated_at
    }
  end
end
