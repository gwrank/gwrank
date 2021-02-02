class Scrim < ApplicationRecord
  belongs_to :captain_a, class_name: 'Player', optional: true
  belongs_to :captain_b, class_name: 'Player', optional: true
  belongs_to :team_a, class_name: 'Team', optional: true
  belongs_to :team_b, class_name: 'Team', optional: true
  belongs_to :winner_team, class_name: 'Team', optional: true

  scope :current_scrims, -> { where('created_at > ?', DateTime.now - 4.hours) }
end
