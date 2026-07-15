class CreateAutomatedTournamentSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :automated_tournament_schedules do |t|
      t.string :discord_server_id, null: false
      t.string :timezone, null: false
      t.string :channel_id, null: false
      t.date :last_reminded_on

      t.timestamps
    end

    add_index :automated_tournament_schedules, :discord_server_id, unique: true
  end
end
