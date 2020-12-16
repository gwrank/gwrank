class AddUsernameToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :username, :string
  end
end
