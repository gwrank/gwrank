class AddGuildNumberToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :guild_number, :integer
  end
end
