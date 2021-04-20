class Character < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :profession, optional: true
  has_many :team_players

  include PgSearch::Model
  multisearchable against: [:igname]

  def igname_with_profession
    if profession.present?
      "#{igname} (#{profession.name})"
    else
      igname
    end
  end
end
