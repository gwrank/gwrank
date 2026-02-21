class AddApiTokenToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :api_token, :string
  end
end
