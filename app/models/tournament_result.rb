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
