class AddExtraFieldsToGuilds < ActiveRecord::Migration[8.1]
  def change
    add_reference :guilds, :leader, null: true, foreign_key: { to_table: :players }
    add_column :guilds, :territory, :string
    add_column :guilds, :faction, :string
    add_column :guilds, :cape_trim, :string
    add_column :guilds, :members_count, :string
    add_column :guilds, :guild_hall, :string
    add_column :guilds, :voip, :string
    add_column :guilds, :voip_url, :string
    add_column :guilds, :announcement, :text
  end
end
