class AddRoundToMatches < ActiveRecord::Migration[6.1]
  def change
    add_column :matches, :round, :integer
    add_column :matches, :number_on_round, :integer
  end
end
