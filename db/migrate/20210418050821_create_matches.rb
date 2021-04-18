class CreateMatches < ActiveRecord::Migration[6.1]
  def change
    create_table :matches do |t|
      t.integer :winner_team

      t.timestamps
    end
  end
end
