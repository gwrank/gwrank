class AddIsCaptainToTeamPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :team_players, :is_captain, :boolean, default: false
  end
end
