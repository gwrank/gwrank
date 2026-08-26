class TeambuildTag < ApplicationRecord
  self.table_name = "team_build_tags"

  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9]+\z/ }

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }

  def self.active_slugs
    active.ordered.pluck(:slug)
  end

  private

  def normalize_slug
    self.slug = slug.presence&.strip&.downcase || name.to_s.strip.parameterize(separator: "")
  end
end
