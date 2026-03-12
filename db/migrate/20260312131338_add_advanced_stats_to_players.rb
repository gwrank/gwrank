class AddAdvancedStatsToPlayers < ActiveRecord::Migration[8.1]
  def change
    # Change average_dpm from integer to float
    change_column :players, :average_dpm, :float

    # Add new stat columns
    add_column :players, :average_dmg_per_game, :float
    add_column :players, :average_deaths_per_game, :float
    add_column :players, :kd_ratio, :float
    add_column :players, :average_team_elo, :integer
    add_column :players, :average_opponent_elo, :integer
  end
end
