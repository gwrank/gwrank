# == Schema Information
#
# Table name: skills
#
#  id                :integer          not null, primary key
#  skill_id          :integer
#  name              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  template_skill_id :integer
#  skill_type        :string
#  is_elite          :boolean          default(FALSE)
#  description       :text
#  profession_id     :integer
#
# Indexes
#
#  index_skills_on_profession_id  (profession_id)
#

class Skill < ApplicationRecord
  belongs_to :profession, optional: true
  has_many :team_player_skills

  def html_image
    ActionController::Base.helpers.image_tag("skills/#{filename}", data: { toggle: 'tooltip', placement: 'bottom', 'original-title': "#{name}. #{skill_type}. #{description}" }, width: 42)
  end

  private

  def filename
    name.gsub(' ', '_').gsub('(', '').gsub(')', '').gsub('\'', '').gsub('"', '').gsub('!', '').gsub(',', '') + '.jpg'
  end
end
