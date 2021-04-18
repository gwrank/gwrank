class Skill < ApplicationRecord
  def html_image
    ActionController::Base.helpers.image_tag("skills/#{filename}", data: { toggle: 'tooltip', placement: 'bottom', 'original-title': name }, width: 42)
  end

  private

  def filename
    name.gsub(' ', '_').gsub('(', '').gsub(')', '').gsub('\'', '').gsub('"', '') + '.jpg'
  end
end
