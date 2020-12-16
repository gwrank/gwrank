class AddOmniauthToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :provider, :string
    add_column :players, :uid, :string
  end
end
