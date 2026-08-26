class CreateTeamBuildTags < ActiveRecord::Migration[8.1]
  def change
    create_table :teambuild_tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :teambuild_tags, :slug, unique: true
    add_index :teambuild_tags, [:active, :position]
  end
end
