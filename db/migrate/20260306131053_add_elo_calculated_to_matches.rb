class AddEloCalculatedToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :elo_calculated, :boolean, default: false
  end
end
