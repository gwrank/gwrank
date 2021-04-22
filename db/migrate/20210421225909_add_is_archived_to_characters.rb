class AddIsArchivedToCharacters < ActiveRecord::Migration[6.1]
  def change
    add_column :characters, :is_archived, :boolean, default: false
  end
end
