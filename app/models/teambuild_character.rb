class TeambuildCharacter < ApplicationRecord
  belongs_to :teambuild
  belongs_to :primary_profession, class_name: "Profession", optional: true
  belongs_to :secondary_profession, class_name: "Profession", optional: true
  belongs_to :elite_skill, class_name: "Skill", optional: true

  validates :position, numericality: { greater_than_or_equal_to: 0 }

  def summary
    {
      name: name,
      primaryProfession: primary_profession&.profession_id,
      secondaryProfession: secondary_profession&.profession_id,
      eliteSkillId: elite_skill&.skill_id,
      assignment: assignment,
      dominantAttribute: dominant_attribute
    }
  end
end
