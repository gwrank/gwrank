class AddSlugToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :slug, :string
  end
end
