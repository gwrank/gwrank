# == Schema Information
#
# Table name: alliances
#
#  id              :bigint           not null, primary key
#  allegiance_rank :string
#  faction         :integer
#  name            :string
#  slug            :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class Alliance < ApplicationRecord
  has_many :guilds, dependent: :nullify
end
