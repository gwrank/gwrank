# == Schema Information
#
# Table name: skills
#
#  id                :bigint           not null, primary key
#  description       :text
#  is_elite          :boolean          default(FALSE)
#  name              :string
#  skill_type        :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  profession_id     :bigint
#  skill_id          :integer
#  template_skill_id :integer
#
# Indexes
#
#  index_skills_on_profession_id  (profession_id)
#
# Foreign Keys
#
#  fk_rails_...  (profession_id => professions.id)
#

class Skill < ApplicationRecord
  belongs_to :profession, optional: true
  has_many :team_player_skills

  def html_image
    ActionController::Base.helpers.image_tag("skills/#{filename}", data: { controller: 'tooltip', bs_toggle: 'tooltip', bs_placement: 'bottom' }, title: "#{name}. #{skill_type}. #{description}", width: 42)
  end

  private

  def filename
    name.gsub(' ', '_').gsub('(', '').gsub(')', '').gsub('\'', '').gsub('"', '').gsub('!', '').gsub(',', '') + '.jpg'
  end
end
