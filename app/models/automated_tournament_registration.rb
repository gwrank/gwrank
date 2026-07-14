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

  scope :for_server, ->(server_id) { where(discord_server_id: server_id) }
  scope :current_for_server, ->(server_id) {
    schedule = AutomatedTournamentSchedule.find_by(discord_server_id: server_id)
    next none unless schedule

    now = Time.now.utc
    lower_bound = schedule.previous_occurrence(from: now) + 2.hours
    upper_bound = schedule.window_boundary(from: now)

    for_server(server_id)
      .where(unregistered_at: nil)
      .where('registered_at > ? AND registered_at <= ?', lower_bound, upper_bound)
  }

  def in_at_queue?(server_id)
    return false unless discord_server_id == server_id && unregistered_at.nil? && registered_at.present?

    schedule = AutomatedTournamentSchedule.find_by(discord_server_id: server_id)
    return false unless schedule

    now = Time.now.utc
    lower_bound = schedule.previous_occurrence(from: now) + 2.hours
    upper_bound = schedule.window_boundary(from: now)

    registered_at > lower_bound && registered_at <= upper_bound
  end
end
