class CreateTeamBuildTags < ActiveRecord::Migration[8.1]
  def change
    create_table :team_build_tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :team_build_tags, :slug, unique: true
    add_index :team_build_tags, [:active, :position]
  end
end
