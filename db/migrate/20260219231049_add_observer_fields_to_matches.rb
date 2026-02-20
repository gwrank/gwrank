class AddObserverFieldsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :exported_at, :datetime
    add_column :matches, :json, :jsonb, default: {}
    add_column :matches, :name, :string
    add_column :matches, :played_at, :datetime
    add_column :matches, :imported_at, :datetime
    add_reference :matches, :imported_by, null: true, foreign_key: { to_table: :players }
  end
end
