class AddAverageWarriorCpmToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :average_warrior_cpm, :integer, default: 0
  end
end
