class AddIgnameHashToCharacters < ActiveRecord::Migration[8.1]
  def change
    add_column :characters, :igname_hash, :string, null: true

    add_index :characters, :igname_hash, unique: true
  end
end
