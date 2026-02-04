# == Schema Information
#
# Table name: team_player_stats
#
#  id             :integer          not null, primary key
#  team_player_id :integer          not null
#  stat_key       :string
#  stat_value     :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_team_player_stats_on_team_player_id  (team_player_id)
#

class TeamPlayerStat < ApplicationRecord
  belongs_to :team_player
end
