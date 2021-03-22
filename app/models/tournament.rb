class Tournament < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  def slug_candidates
    [ "#{year}-#{month}" ]
  end
end
