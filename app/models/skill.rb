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
