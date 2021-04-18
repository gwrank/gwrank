class AddSecondaryProfessionAndPositionToTeamPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :team_players, :secondary_profession_id, :integer
    add_column :team_players, :position, :integer
  end
end
