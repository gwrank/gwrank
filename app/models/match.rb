class Match < ApplicationRecord
  belongs_to :tournament, optional: true
  belongs_to :winner_team, class_name: 'Team', optional: true
  has_many :teams, dependent: :destroy
end
