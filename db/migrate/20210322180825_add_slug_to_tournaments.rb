class AddSlugToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :slug, :string
    add_index :tournaments, :slug, unique: true
  end
end
