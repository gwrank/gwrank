class AddSkillTypeToSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :skills, :skill_type, :string
  end
end
