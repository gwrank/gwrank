# == Schema Information
#
# Table name: automated_tournament_registrations
#
#  id                :bigint           not null, primary key
#  registered_at     :datetime
#  unregistered_at   :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  discord_server_id :string           not null
#  player_id         :bigint           not null
#
# Indexes
#
#  idx_on_discord_server_id_registered_at_deded07a53              (discord_server_id,registered_at)
#  index_automated_tournament_registrations_on_discord_server_id  (discord_server_id)
#  index_automated_tournament_registrations_on_player_id          (player_id)
#

class AutomatedTournamentRegistration < ApplicationRecord
  belongs_to :player

  scope :current_registrations, -> { where('registered_at > ?', DateTime.now - 8.hours).where(unregistered_at: nil) }
  scope :for_server, ->(server_id) { where(discord_server_id: server_id) }
  scope :current_for_server, ->(server_id) { current_registrations.for_server(server_id) }

  def in_at_queue?(server_id)
    discord_server_id == server_id && unregistered_at.nil? && registered_at > DateTime.now - 8.hours
  end
end
