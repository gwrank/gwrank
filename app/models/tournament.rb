class Tournament < ApplicationRecord
  has_many :comments, as: :commentable
  has_many :matches, dependent: :destroy
  has_many :tournament_results, dependent: :destroy

  scope :monthly, -> { where(tournament_type: 'mat') }
  scope :daily, -> { where(tournament_type: 'at') }

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

  def winner_guild
    tournament_results.final_standings.find_by(position: 1)&.guild
  end
end
