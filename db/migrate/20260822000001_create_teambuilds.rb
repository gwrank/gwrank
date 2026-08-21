class CreateTeambuilds < ActiveRecord::Migration[8.1]
  def change
    create_table :teambuilds do |t|
      t.references :player, null: false, foreign_key: true
      t.uuid :source_uuid, null: false
      t.string :name
      t.string :tags, array: true, default: []
      t.string :game_mode, default: ""
      t.integer :player_count
      t.string :visibility, null: false, default: "private"
      t.jsonb :document, null: false
      t.string :document_hash
      t.timestamps
    end

    add_index :teambuilds, [:player_id, :source_uuid], unique: true
    add_index :teambuilds, :visibility
    add_index :teambuilds, :player_count
    add_index :teambuilds, :updated_at
    add_index :teambuilds, :tags, using: "gin"

    create_table :teambuild_characters do |t|
      t.references :teambuild, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :name
      t.string :assignment
      t.references :primary_profession, foreign_key: { to_table: :professions }
      t.references :secondary_profession, foreign_key: { to_table: :professions }
      t.references :elite_skill, foreign_key: { to_table: :skills }
      t.string :dominant_attribute
      t.timestamps
    end

    add_index :teambuild_characters, [:teambuild_id, :position], unique: true

    add_column :skills, :campaign, :string
  end
end
