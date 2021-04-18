class Tournament < ApplicationRecord
  has_many :matches, dependent: :destroy

  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  def slug_candidates
    [ "#{year}-#{month}" ]
  end

  def title
    "#{year}-#{month}"
  end
end
