# == Schema Information
#
# Table name: team_player_skills
#
#  id             :bigint           not null, primary key
#  position       :integer          default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  skill_id       :bigint           not null
#  team_player_id :bigint           not null
#
# Indexes
#
#  index_team_player_skills_on_skill_id        (skill_id)
#  index_team_player_skills_on_team_player_id  (team_player_id)
#
# Foreign Keys
#
#  fk_rails_...  (skill_id => skills.id)
#  fk_rails_...  (team_player_id => team_players.id)
#
class TeamPlayerSkill < ApplicationRecord
  belongs_to :team_player
  belongs_to :skill
end
