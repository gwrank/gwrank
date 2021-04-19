class CreateCharacters < ActiveRecord::Migration[6.1]
  def change
    create_table :characters do |t|
      t.references :player, null: true, foreign_key: true
      t.string :igname
      t.references :profession, null: true, foreign_key: true

      t.timestamps
    end
    add_index :characters, :igname, unique: true
  end
end
