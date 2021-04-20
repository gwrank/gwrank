class CreateTournamentResults < ActiveRecord::Migration[6.1]
  def change
    create_table :tournament_results do |t|
      t.references :tournament, null: false, foreign_key: true
      t.integer :round, default: 0
      t.integer :position
      t.integer :trim, default: 0
      t.references :guild, null: false, foreign_key: true

      t.timestamps
    end
    add_index :tournament_results, :round
  end
end
