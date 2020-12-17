class AddIgnameToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :igname, :string
  end
end
