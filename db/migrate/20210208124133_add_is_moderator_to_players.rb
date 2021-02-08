class AddIsModeratorToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :is_moderator, :boolean, default: false
  end
end
