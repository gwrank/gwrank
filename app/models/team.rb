# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  rank       :integer
#  rating     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  guild_id   :bigint
#  match_id   :bigint
#
# Indexes
#
#  index_teams_on_guild_id  (guild_id)
#  index_teams_on_match_id  (match_id)
#
# Foreign Keys
#
#  fk_rails_...  (guild_id => guilds.id)
#  fk_rails_...  (match_id => matches.id)
#

class Team < ApplicationRecord
  belongs_to :guild, optional: true
  belongs_to :match, optional: true
  has_many :team_players, dependent: :destroy
  has_many :players, through: :team_players
end
