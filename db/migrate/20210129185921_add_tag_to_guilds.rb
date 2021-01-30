class AddTagToGuilds < ActiveRecord::Migration[6.1]
  def change
    add_column :guilds, :tag, :string
  end
end
