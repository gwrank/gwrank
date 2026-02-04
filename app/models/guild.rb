# == Schema Information
#
# Table name: guilds
#
#  id                 :bigint           not null, primary key
#  bronze_trims_count :integer          default(0)
#  gold_trims_count   :integer          default(0)
#  is_archived        :boolean          default(FALSE)
#  name               :string
#  region             :string
#  silver_trims_count :integer          default(0)
#  slug               :string
#  tag                :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  owner_id           :integer
#
# Indexes
#
#  index_guilds_on_slug  (slug) UNIQUE
#
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

  def gold_trims_count
    tournament_results.gold_trims.count
  end
end
