class AddClaimedIgnameToCharacterClaims < ActiveRecord::Migration[8.1]
  def change
    add_column :character_claims, :claimed_igname, :string
    add_index :character_claims, :claimed_igname
  end
end