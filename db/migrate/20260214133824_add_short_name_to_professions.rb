class AddShortNameToProfessions < ActiveRecord::Migration[8.1]
  def change
    add_column :professions, :short_name, :string
  end
end
