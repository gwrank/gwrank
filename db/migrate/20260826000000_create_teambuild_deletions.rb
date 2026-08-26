class CreateTeambuildDeletions < ActiveRecord::Migration[8.1]
  def change
    create_table :teambuild_deletions do |t|
      t.references :player, foreign_key: { on_delete: :nullify }
      t.uuid :source_uuid, null: false
      t.string :visibility, null: false
      t.datetime :deleted_at, null: false
      t.timestamps
    end

    add_index :teambuild_deletions, :deleted_at
    add_index :teambuild_deletions, [:player_id, :source_uuid]
  end
end
