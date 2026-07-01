# == Schema Information
#
# Table name: scrims
#
#  id             :bigint           not null, primary key
#  team_a_wins    :integer          default(0), not null
#  team_b_wins    :integer          default(0), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  captain_a_id   :integer
#  captain_b_id   :integer
#  team_a_id      :integer
#  team_b_id      :integer
#  winner_team_id :integer
#

class Scrim < ApplicationRecord
  belongs_to :captain_a, class_name: 'Player', optional: true
  belongs_to :captain_b, class_name: 'Player', optional: true
  belongs_to :team_a, class_name: 'Team', optional: true
  belongs_to :team_b, class_name: 'Team', optional: true
  belongs_to :winner_team, class_name: 'Team', optional: true

  scope :current_scrims, -> { where('created_at > ?', DateTime.now - 8.hours) }
  scope :decided, -> { where.not(winner_team_id: nil) }
  scope :in_progress, -> { where(winner_team_id: nil).where.not(team_a_id: nil) }

  def loser_team
    return nil unless winner_team_id

    winner_team_id == team_a_id ? team_b : team_a
  end

  def calculate_elo!
    return unless winner_team && loser_team

    EloCalculator.new(winner_team: winner_team, loser_team: loser_team).call!
    self
  end
end
