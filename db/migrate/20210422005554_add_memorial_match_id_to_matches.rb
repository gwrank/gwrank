class AddMemorialMatchIdToMatches < ActiveRecord::Migration[6.1]
  def change
    add_column :matches, :memorial_match_id, :integer
  end
end
