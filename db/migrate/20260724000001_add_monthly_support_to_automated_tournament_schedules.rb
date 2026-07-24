class AddMonthlySupportToAutomatedTournamentSchedules < ActiveRecord::Migration[7.0]
  def change
    add_column :automated_tournament_schedules, :is_monthly, :boolean, default: false
    add_column :automated_tournament_schedules, :recurrence_pattern, :string
    add_column :automated_tournament_schedules, :registration_opens_days_before, :integer, default: 28
    
    # Set existing records as daily
    reversible do |dir|
      dir.up do
        execute "UPDATE automated_tournament_schedules SET is_monthly = false, recurrence_pattern = CONCAT('daily_', timezone) WHERE is_monthly IS NULL"
      end
    end
  end
end
