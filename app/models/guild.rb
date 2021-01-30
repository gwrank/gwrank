class Guild < ApplicationRecord
  belongs_to :owner, class_name: 'Player'
  has_many :players

  extend FriendlyId
  friendly_id :name, use: :slugged

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :tag

  def name_with_tag
    "#{name} [#{tag}]"
  end
end
