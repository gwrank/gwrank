# == Schema Information
#
# Table name: scrims
#
#  id             :integer          not null, primary key
#  team_a_id      :integer
#  team_b_id      :integer
#  captain_a_id   :integer
#  captain_b_id   :integer
#  winner_team_id :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class Scrim < ApplicationRecord
  belongs_to :captain_a, class_name: 'Player', optional: true
  belongs_to :captain_b, class_name: 'Player', optional: true
  belongs_to :team_a, class_name: 'Team', optional: true
  belongs_to :team_b, class_name: 'Team', optional: true
  belongs_to :winner_team, class_name: 'Team', optional: true

  scope :current_scrims, -> { where('created_at > ?', DateTime.now - 8.hours) }
end
