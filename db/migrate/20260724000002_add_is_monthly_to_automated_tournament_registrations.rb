class AddIsMonthlyToAutomatedTournamentRegistrations < ActiveRecord::Migration[7.0]
  def change
    add_column :automated_tournament_registrations, :is_monthly, :boolean, default: false
  end
end
