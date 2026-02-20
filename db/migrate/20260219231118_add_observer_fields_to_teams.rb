class AddObserverFieldsToTeams < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :rank, :integer
    add_column :teams, :rating, :integer
  end
end
