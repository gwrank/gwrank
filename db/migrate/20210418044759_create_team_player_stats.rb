class CreateTeamPlayerStats < ActiveRecord::Migration[6.1]
  def change
    create_table :team_player_stats do |t|
      t.references :team_player, null: false, foreign_key: true
      t.string :stat_key
      t.integer :stat_value

      t.timestamps
    end
  end
end
