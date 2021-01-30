class AddGuildReferencesToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_reference :players, :guild, null: true, foreign_key: true
  end
end
