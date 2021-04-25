class AddProfessionReferencesToSkills < ActiveRecord::Migration[6.1]
  def change
    add_reference :skills, :profession, null: true, foreign_key: true
  end
end
