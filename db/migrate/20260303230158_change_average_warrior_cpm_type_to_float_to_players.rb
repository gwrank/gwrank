class ChangeAverageWarriorCpmTypeToFloatToPlayers < ActiveRecord::Migration[8.1]
  def change
    change_column :players, :average_warrior_cpm, :float
  end
end
