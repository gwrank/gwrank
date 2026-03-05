# == Schema Information
#
# Table name: professions
#
#  id            :bigint           not null, primary key
#  name          :string
#  short_name    :string
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
      ActionController::Base.helpers.image_tag("professions/#{name}.png", data: { controller: 'tooltip', bs_toggle: 'tooltip', bs_placement: 'bottom' }, title: name, width: 33, loading: 'lazy')
    end
  end

  def html_image_simple(size: 33)
    if name.eql?('None')
      ''
    else
      ActionController::Base.helpers.image_tag("professions/#{name}.png", title: name, width: size, loading: 'lazy')
    end
  end
end
