# == Schema Information
#
# Table name: teams
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  match_id   :integer
#  guild_id   :integer
#
# Indexes
#
#  index_teams_on_guild_id  (guild_id)
#  index_teams_on_match_id  (match_id)
#

class Team < ApplicationRecord
  belongs_to :guild, optional: true
  belongs_to :match, optional: true
  has_many :team_players, dependent: :destroy
  has_many :players, through: :team_players
end
