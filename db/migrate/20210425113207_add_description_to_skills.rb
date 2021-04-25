class AddDescriptionToSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :skills, :description, :text
  end
end
