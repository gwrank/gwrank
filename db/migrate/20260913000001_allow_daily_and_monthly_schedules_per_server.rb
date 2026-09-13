class AllowDailyAndMonthlySchedulesPerServer < ActiveRecord::Migration[8.1]
  def change
    # is_monthly was added without NOT NULL, so NULLs may exist. Postgres
    # treats NULLs as distinct in unique indexes, so backfill first to keep
    # the new composite index sound.
    reversible do |dir|
      dir.up do
        execute "UPDATE automated_tournament_schedules SET is_monthly = false WHERE is_monthly IS NULL"
      end
    end
    change_column_null :automated_tournament_schedules, :is_monthly, false

    # Monthly schedules have no daily slot, so timezone must be nullable.
    change_column_null :automated_tournament_schedules, :timezone, true

    # One daily AND one monthly schedule per server (was: one row per server).
    remove_index :automated_tournament_schedules, :discord_server_id
    add_index :automated_tournament_schedules, %i[discord_server_id is_monthly],
              unique: true, name: "index_at_schedules_on_server_and_monthly"
  end
end
