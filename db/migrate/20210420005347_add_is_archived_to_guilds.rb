class AddIsArchivedToGuilds < ActiveRecord::Migration[6.1]
  def change
    add_column :guilds, :is_archived, :boolean, default: false
  end
end
