class AddWinnerTeamToMatches < ActiveRecord::Migration[6.1]
  def change
    add_column :matches, :winner_team_id, :integer
  end
end
