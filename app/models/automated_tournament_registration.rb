# == Schema Information
#
# Table name: automated_tournament_registrations
#
#  id                :bigint           not null, primary key
#  is_monthly        :boolean          default(FALSE)
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
  scope :monthly, -> { where(is_monthly: true) }
  scope :daily, -> { where(is_monthly: false) }
  scope :current_for_server, ->(server_id) {
    bounds = window_bounds(server_id)
    next none unless bounds

    for_server(server_id)
      .daily
      .where(unregistered_at: nil)
      .where('registered_at > ? AND registered_at <= ?', *bounds)
  }
  scope :current_monthly_for_server, ->(server_id) {
    bounds = monthly_window_bounds(server_id)
    next none unless bounds

    for_server(server_id)
      .monthly
      .where(unregistered_at: nil)
      .where('registered_at > ? AND registered_at <= ?', *bounds)
  }

  def in_at_queue?(server_id)
    return false unless discord_server_id == server_id && unregistered_at.nil? && registered_at.present?

    bounds = self.class.window_bounds(server_id)
    return false unless bounds

    registered_at > bounds.first && registered_at <= bounds.last
  end

  # Internal helper shared by the scope and instance predicate above. Not
  # marked private: private_class_method methods can't be reached through
  # an explicit receiver (self.class.window_bounds) or through the
  # public_send-based delegation a scope block uses to reach class methods.
  def self.window_bounds(server_id)
    schedule = AutomatedTournamentSchedule.daily.find_by(discord_server_id: server_id)
    return nil unless schedule

    now = Time.now.utc
    [schedule.previous_occurrence(from: now) + 2.hours, schedule.window_boundary(from: now)]
  end

  def self.monthly_window_bounds(server_id)
    schedule = AutomatedTournamentSchedule.monthly.find_by(discord_server_id: server_id)
    return nil unless schedule

    now = Time.now.utc
    [schedule.previous_occurrence(from: now) + 2.hours, schedule.window_boundary(from: now)]
  end
end
