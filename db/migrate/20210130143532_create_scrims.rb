class CreateScrims < ActiveRecord::Migration[6.1]
  def change
    create_table :scrims do |t|
      t.integer :team_a_id
      t.integer :team_b_id
      t.integer :captain_a_id
      t.integer :captain_b_id
      t.integer :winner_team_id

      t.timestamps
    end
  end
end
