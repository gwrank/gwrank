class AddIsEliteToSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :skills, :is_elite, :boolean, default: false
  end
end
