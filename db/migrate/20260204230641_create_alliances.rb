class CreateAlliances < ActiveRecord::Migration[8.1]
  def change
    create_table :alliances do |t|
      t.string :name
      t.string :slug
      t.string :allegiance_rank
      t.integer :faction

      t.timestamps
    end
  end
end
