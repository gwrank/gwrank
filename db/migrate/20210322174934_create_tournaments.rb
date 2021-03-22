class CreateTournaments < ActiveRecord::Migration[6.1]
  def change
    create_table :tournaments do |t|
      t.integer :year
      t.integer :month

      t.timestamps
    end
  end
end
