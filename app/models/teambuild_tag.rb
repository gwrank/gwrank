# == Schema Information
#
# Table name: teambuild_tags
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  position   :integer          default(0), not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_teambuild_tags_on_active_and_position  (active,position)
#  index_teambuild_tags_on_slug                 (slug) UNIQUE
#
class TeambuildTag < ApplicationRecord
  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: true,
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
