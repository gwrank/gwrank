class Character < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :profession, optional: true
  has_many :team_players

  scope :active, -> { where(is_archived: false) }
  scope :archived, -> { where(is_archived: true) }

  validates :igname, presence: true
  validates :igname, uniqueness: true

  include PgSearch::Model
  multisearchable against: [:igname]
  pg_search_scope :whose_igname_starts_with,
                  against: :igname,
                  using: {
                    tsearch: { prefix: true }
                  }

  def igname_with_profession
    if profession.present?
      "#{igname} (#{profession.name})"
    else
      igname
    end
  end
end
