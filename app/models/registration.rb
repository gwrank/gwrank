# == Schema Information
#
# Table name: registrations
#
#  id              :integer          not null, primary key
#  player_id       :integer          not null
#  registered_at   :datetime
#  unregistered_at :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_registrations_on_player_id  (player_id)
#

class Registration < ApplicationRecord
  belongs_to :player

  scope :current_registrations, -> { where('registered_at > ?', DateTime.now - 8.hours).where(unregistered_at: nil) }
  scope :afk_registrations, -> { where('registered_at > ?', DateTime.now - 8.hours).where.not(unregistered_at: nil) }
end
