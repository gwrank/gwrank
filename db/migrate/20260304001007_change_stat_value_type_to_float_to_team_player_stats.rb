class ChangeStatValueTypeToFloatToTeamPlayerStats < ActiveRecord::Migration[8.1]
  def change
    change_column :team_player_stats, :stat_value, :float
  end
end
