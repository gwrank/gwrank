class AddTournamentTypeToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :tournament_type, :string
    add_index :tournaments, :tournament_type
  end
end
