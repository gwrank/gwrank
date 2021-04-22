class RemoveWinnerTeamFromMatches < ActiveRecord::Migration[6.1]
  def change
    remove_column :matches, :winner_team, :integer
  end
end
