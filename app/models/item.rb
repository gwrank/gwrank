class Item < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  include PgSearch::Model
  multisearchable against: [:title]
  pg_search_scope :whose_title_starts_with,
                  against: :title,
                  using: {
                    tsearch: { prefix: true }
                  }
end
