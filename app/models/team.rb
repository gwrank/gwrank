class Team < ApplicationRecord
  belongs_to :guild, optional: true
  belongs_to :match, optional: true
  has_many :team_players, dependent: :destroy
  has_many :players, through: :team_players
end
