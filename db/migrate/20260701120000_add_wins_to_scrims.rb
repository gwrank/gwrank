class AddWinsToScrims < ActiveRecord::Migration[8.1]
  def change
    add_column :scrims, :team_a_wins, :integer, null: false, default: 0
    add_column :scrims, :team_b_wins, :integer, null: false, default: 0
  end
end
