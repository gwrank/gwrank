class AddTwitchUsernameToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :twitch_username, :string
  end
end
