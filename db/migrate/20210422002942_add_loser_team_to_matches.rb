class AddLoserTeamToMatches < ActiveRecord::Migration[6.1]
  def change
    add_column :matches, :loser_team_id, :integer
  end
end
