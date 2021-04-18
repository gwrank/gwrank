class AddProfessionIdToProfessions < ActiveRecord::Migration[6.1]
  def change
    add_column :professions, :profession_id, :integer
  end
end
