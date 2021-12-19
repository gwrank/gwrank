class AddTrimsCountToGuilds < ActiveRecord::Migration[6.1]
  def change
    add_column :guilds, :gold_trims_count, :integer, default: 0
    add_column :guilds, :silver_trims_count, :integer, default: 0
    add_column :guilds, :bronze_trims_count, :integer, default: 0
  end
end
