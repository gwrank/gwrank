class AddIgnameToTeamPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :team_players, :igname, :string
  end
end
