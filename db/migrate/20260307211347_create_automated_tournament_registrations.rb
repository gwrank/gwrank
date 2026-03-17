class CreateAutomatedTournamentRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :automated_tournament_registrations do |t|
      t.bigint :player_id, null: false
      t.string :discord_server_id, null: false
      t.datetime :registered_at
      t.datetime :unregistered_at

      t.timestamps
    end

    add_index :automated_tournament_registrations, :player_id
    add_index :automated_tournament_registrations, [:discord_server_id, :registered_at]
    add_index :automated_tournament_registrations, :discord_server_id
  end
end
