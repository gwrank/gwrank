class AddAverageDpmToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :average_dpm, :integer, default: 0
  end
end
