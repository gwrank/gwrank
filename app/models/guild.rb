# == Schema Information
#
# Table name: guilds
#
#  id                 :bigint           not null, primary key
#  announcement       :text
#  bronze_trims_count :integer          default(0)
#  cape_trim          :string
#  faction            :string
#  gold_trims_count   :integer          default(0)
#  guild_hall         :string
#  is_archived        :boolean          default(FALSE)
#  members_count      :string
#  name               :string
#  region             :string
#  silver_trims_count :integer          default(0)
#  slug               :string
#  tag                :string
#  territory          :string
#  voip               :string
#  voip_url           :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  alliance_id        :bigint
#  leader_id          :bigint
#  owner_id           :integer
#
# Indexes
#
#  index_guilds_on_alliance_id  (alliance_id)
#  index_guilds_on_leader_id    (leader_id)
#  index_guilds_on_slug         (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (alliance_id => alliances.id)
#  fk_rails_...  (leader_id => players.id)
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
  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

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
