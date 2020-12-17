class AddIsVerifiedToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :is_verified, :boolean, default: false
  end
end
