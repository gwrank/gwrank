class AddLastRegistrationRemindedForToAutomatedTournamentSchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :automated_tournament_schedules, :last_registration_reminded_for, :date
  end
end
