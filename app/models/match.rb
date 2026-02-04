# == Schema Information
#
# Table name: matches
#
#  id                :integer          not null, primary key
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  tournament_id     :integer
#  round             :integer
#  number_on_round   :integer
#  loser_team_id     :integer
#  winner_team_id    :integer
#  memorial_match_id :integer
#
# Indexes
#
#  index_matches_on_tournament_id  (tournament_id)
#

class Match < ApplicationRecord
  belongs_to :loser_team, class_name: 'Team', optional: true
  belongs_to :tournament, optional: true
  belongs_to :winner_team, class_name: 'Team', optional: true
  has_many :comments, as: :commentable
  has_many :movies, as: :movieable
  has_many :teams, dependent: :destroy

  def title
    title = []
    teams.each do |team|
      title << team.guild.name_with_tag
    end
    title.join(' vs. ')
  end

  def round_text
    case round
    when 1
      'Playoff'
    when 2
      'Quarterfinal'
    when 3
      'Semifinal'
    when 4
      'Final'
    end
  end
end
