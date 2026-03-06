class AddEloRatingToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :elo_rating, :integer
    add_column :players, :elo_matches, :integer
  end
end
