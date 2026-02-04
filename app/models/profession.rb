# == Schema Information
#
# Table name: professions
#
#  id            :bigint           not null, primary key
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  profession_id :integer
#

class Profession < ApplicationRecord
  has_many :characters
  has_many :skills
  has_many :team_players

  def html_image
    if name.eql?('None')
      ''
    else
      ActionController::Base.helpers.image_tag("professions/#{name}.png", data: { toggle: 'tooltip', placement: 'bottom', 'original-title': name }, width: 20)
    end
  end
end
