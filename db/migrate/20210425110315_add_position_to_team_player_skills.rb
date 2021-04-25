class AddPositionToTeamPlayerSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :team_player_skills, :position, :integer, default: 0
  end
end
