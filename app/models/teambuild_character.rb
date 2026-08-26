# == Schema Information
#
# Table name: teambuild_characters
#
#  id                      :bigint           not null, primary key
#  assignment              :string
#  dominant_attribute      :string
#  name                    :string
#  position                :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  elite_skill_id          :bigint
#  primary_profession_id   :bigint
#  secondary_profession_id :bigint
#  teambuild_id            :bigint           not null
#
# Indexes
#
#  index_teambuild_characters_on_elite_skill_id             (elite_skill_id)
#  index_teambuild_characters_on_primary_profession_id      (primary_profession_id)
#  index_teambuild_characters_on_secondary_profession_id    (secondary_profession_id)
#  index_teambuild_characters_on_teambuild_id               (teambuild_id)
#  index_teambuild_characters_on_teambuild_id_and_position  (teambuild_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (elite_skill_id => skills.id)
#  fk_rails_...  (primary_profession_id => professions.id)
#  fk_rails_...  (secondary_profession_id => professions.id)
#  fk_rails_...  (teambuild_id => teambuilds.id)
#
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
