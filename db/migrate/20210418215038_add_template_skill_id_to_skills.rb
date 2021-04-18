class AddTemplateSkillIdToSkills < ActiveRecord::Migration[6.1]
  def change
    add_column :skills, :template_skill_id, :integer
  end
end
