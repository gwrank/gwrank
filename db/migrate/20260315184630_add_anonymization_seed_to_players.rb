class AddAnonymizationSeedToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :anonymization_seed, :string, null: true, default: nil
  end
end
