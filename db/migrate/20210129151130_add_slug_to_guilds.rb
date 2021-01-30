class AddSlugToGuilds < ActiveRecord::Migration[6.1]
  def change
    add_column :guilds, :slug, :string
    add_index :guilds, :slug, unique: true
  end
end
