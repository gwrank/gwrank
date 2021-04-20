class Guild < ApplicationRecord
  belongs_to :owner, class_name: 'Player', optional: true
  has_many :players
  has_many :teams
  has_many :tournament_results

  scope :active, -> { where(is_archived: false) }
  scope :archived, -> { where(is_archived: true) }

  extend FriendlyId
  friendly_id :name, use: :slugged

  include PgSearch::Model
  multisearchable against: [:name, :tag]
  pg_search_scope :whose_name_starts_with,
                  against: :name,
                  using: {
                    tsearch: { prefix: true }
                  }
  pg_search_scope :whose_tag_is,
                  against: :tag

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :tag

  def name_with_tag
    "#{name} [#{tag}]"
  end

  def best_position
    if tournament_results.final_standings.order(position: :asc).first
      tournament_results.final_standings.order(position: :asc).first&.position
    else
      'Unknown'
    end
  end
end
