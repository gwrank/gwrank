class CreateTeamPlayers < ActiveRecord::Migration[6.1]
  def change
    create_table :team_players do |t|
      t.references :team, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :profession, null: true, foreign_key: true

      t.timestamps
    end
  end
end
