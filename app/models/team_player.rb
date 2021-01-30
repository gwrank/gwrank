class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :player
  belongs_to :profession
end
