class AddGuildReferencesToTeams < ActiveRecord::Migration[6.1]
  def change
    add_reference :teams, :guild, null: true, foreign_key: true
  end
end
