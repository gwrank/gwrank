class AddDateToTournaments < ActiveRecord::Migration[6.1]
  def change
    add_column :tournaments, :date, :date
  end
end
