# == Schema Information
#
# Table name: tournament_results
#
#  id            :bigint           not null, primary key
#  position      :integer
#  round         :integer          default(0)
#  trim          :integer          default(0)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  guild_id      :bigint           not null
#  tournament_id :bigint           not null
#
# Indexes
#
#  index_tournament_results_on_guild_id       (guild_id)
#  index_tournament_results_on_round          (round)
#  index_tournament_results_on_tournament_id  (tournament_id)
#
# Foreign Keys
#
#  fk_rails_...  (guild_id => guilds.id)
#  fk_rails_...  (tournament_id => tournaments.id)
#
class TournamentResult < ApplicationRecord
  belongs_to :tournament
  belongs_to :guild

  scope :gold_trims, -> { where(trim: 1) }
  scope :silver_trims, -> { where(trim: 2) }
  scope :bronze_trims, -> { where(trim: 3) }
  scope :with_trims, -> { where('trim IN (?)', [1, 2, 3]) }
  scope :swiss_rounds_results, -> { where(round: 1) }
  scope :final_standings, -> { where(round: 2) }

  def trim_text
    case trim
    when 1
      'Gold'
    when 2
      'Silver'
    when 3
      'Bronze'
    end
  end
end
