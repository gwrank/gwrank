class CreateTeamPlayerSkills < ActiveRecord::Migration[6.1]
  def change
    create_table :team_player_skills do |t|
      t.references :team_player, null: false, foreign_key: true
      t.references :skill, null: false, foreign_key: true

      t.timestamps
    end
  end
end
