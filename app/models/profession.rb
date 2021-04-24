class Profession < ApplicationRecord
  has_many :team_players

  def html_image
    if name.eql?('None')
      ''
    else
      ActionController::Base.helpers.image_tag("professions/#{name}.png", data: { toggle: 'tooltip', placement: 'bottom', 'original-title': name }, width: 20)
    end
  end
end
