class AddMatchReferencesToTeams < ActiveRecord::Migration[6.1]
  def change
    add_reference :teams, :match, null: true, foreign_key: true
  end
end
