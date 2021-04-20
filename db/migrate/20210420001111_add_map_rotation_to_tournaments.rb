class AddMapRotationToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :map_rotation, :string
  end
end
