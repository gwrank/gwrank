class Guild < ApplicationRecord
  belongs_to :owner, class_name: 'Player', optional: true
  has_many :players
  has_many :teams
  has_many :tournament_results

  scope :active, -> { where(is_archived: false) }
  scope :archived, -> { where(is_archived: true) }

  extend FriendlyId
  friendly_id :name, use: :slugged

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :tag

  def name_with_tag
    "#{name} [#{tag}]"
  end
end
