class AddProfessionsToPlayers < ActiveRecord::Migration[6.1]
  def change
    add_column :players, :is_warrior, :boolean, default: false
    add_column :players, :is_ranger, :boolean, default: false
    add_column :players, :is_monk, :boolean, default: false
    add_column :players, :is_necromancer, :boolean, default: false
    add_column :players, :is_mesmer, :boolean, default: false
    add_column :players, :is_elementalist, :boolean, default: false
    add_column :players, :is_assassin, :boolean, default: false
    add_column :players, :is_ritualist, :boolean, default: false
    add_column :players, :is_paragon, :boolean, default: false
    add_column :players, :is_dervish, :boolean, default: false
  end
end
