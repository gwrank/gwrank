class AddCharacterReferencesToTeamPlayers < ActiveRecord::Migration[6.1]
  def change
    add_reference :team_players, :character, null: true, foreign_key: true
  end
end
