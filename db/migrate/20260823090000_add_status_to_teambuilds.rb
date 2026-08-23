class AddStatusToTeambuilds < ActiveRecord::Migration[8.1]
  def change
    add_column :teambuilds, :status, :string, null: false, default: "published"
    add_index :teambuilds, :status
  end
end
