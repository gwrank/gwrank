# == Schema Information
#
# Table name: tournaments
#
#  id              :bigint           not null, primary key
#  date            :date
#  guild_number    :integer
#  map_rotation    :string
#  month           :integer
#  slug            :string
#  tournament_type :string
#  year            :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_tournaments_on_slug             (slug) UNIQUE
#  index_tournaments_on_tournament_type  (tournament_type)
#

class Tournament < ApplicationRecord
  has_many :comments, as: :commentable
  has_many :matches, dependent: :destroy
  has_many :tournament_results, dependent: :destroy

  scope :monthly, -> { where(tournament_type: 'mat') }
  scope :daily, -> { where(tournament_type: 'at') }

  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged
  def should_generate_new_friendly_id?
    slug.blank? || tournament_type_changed? || date_changed?
  end

  def slug_candidates
    case tournament_type
    when 'at'
      ["#{date}-at"]
    when 'mat'
      ["#{year}-#{month}-mat"]
    end
  end

  def title
    case tournament_type
    when 'at'
      "#{date} AT"
    when 'mat'
      "#{year}/#{month} mAT"
    else
      date
    end
  end

  def winner_guild
    tournament_results.final_standings.find_by(position: 1)&.guild
  end
end
