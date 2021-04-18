class Tournament < ApplicationRecord
  has_many :matches, dependent: :destroy

  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  def slug_candidates
    [ "#{year}-#{month}" ]
  end

  def title
    "#{year}-#{month} Tournament Series Championship GvG Results"
  end

  def year_and_month
    "#{year}-#{month}"
  end
end
