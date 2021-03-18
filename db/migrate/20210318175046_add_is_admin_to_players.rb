class AddIsAdminToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :is_admin, :boolean, default: false
  end
end
