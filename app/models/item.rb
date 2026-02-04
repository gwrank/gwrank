# == Schema Information
#
# Table name: items
#
#  id              :bigint           not null, primary key
#  campaign        :string
#  canonical_title :string
#  categories      :string           default([]), is an Array
#  common_salvage  :string
#  image           :jsonb
#  notes           :jsonb
#  parts           :string           default([]), is an Array
#  rare_salvage    :string
#  rarity          :string
#  raw_infobox     :jsonb
#  rolls           :jsonb
#  slug            :string
#  source_url      :string
#  stats           :jsonb
#  subtype         :string
#  title           :string
#  type            :string
#  value           :integer
#  weapon_range    :string
#  weapon_type     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
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
