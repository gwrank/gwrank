# == Schema Information
#
# Table name: characters
#
#  id            :integer          not null, primary key
#  player_id     :integer
#  igname        :string
#  profession_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  is_archived   :boolean          default(FALSE)
#
# Indexes
#
#  index_characters_on_igname         (igname) UNIQUE
#  index_characters_on_player_id      (player_id)
#  index_characters_on_profession_id  (profession_id)
#

class Character < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :profession, optional: true
  has_many :team_players

  scope :active, -> { where(is_archived: false) }
  scope :archived, -> { where(is_archived: true) }

  validates :igname, presence: true
  validates :igname, uniqueness: true

  include PgSearch::Model
  multisearchable against: [:igname]
  pg_search_scope :whose_igname_starts_with,
                  against: :igname,
                  using: {
                    tsearch: { prefix: true }
                  }

  def igname_with_profession
    if profession.present?
      "#{igname} (#{profession.name})"
    else
      igname
    end
  end
end
