# == Schema Information
#
# Table name: team_player_stats
#
#  id             :bigint           not null, primary key
#  stat_key       :string
#  stat_value     :float
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  team_player_id :bigint           not null
#
# Indexes
#
#  index_team_player_stats_on_team_player_id  (team_player_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_player_id => team_players.id)
#

class TeamPlayerStat < ApplicationRecord
  belongs_to :team_player
end
