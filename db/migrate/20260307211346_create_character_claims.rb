class CreateCharacterClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :character_claims do |t|
      t.references :character, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :claimed_by, type: :bigint, foreign_key: { to_table: 'players' }
      t.string :status, default: 'pending'

      t.timestamps
    end

    # Add unique index only for pending claims (to prevent duplicate pending claims)
    add_index :character_claims, [:character_id, :player_id], unique: true, where: "status = 'pending'"
  end
end
