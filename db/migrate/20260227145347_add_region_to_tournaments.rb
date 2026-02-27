class AddRegionToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :region, :string
  end
end
