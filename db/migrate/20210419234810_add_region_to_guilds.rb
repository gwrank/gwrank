class AddRegionToGuilds < ActiveRecord::Migration[6.1]
  def change
    add_column :guilds, :region, :string
  end
end
