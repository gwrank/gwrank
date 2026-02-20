class AddAllianceToGuilds < ActiveRecord::Migration[8.1]
  def change
    add_reference :guilds, :alliance, null: true, foreign_key: true
  end
end
