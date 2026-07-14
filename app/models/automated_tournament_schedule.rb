# == Schema Information
#
# Table name: automated_tournament_schedules
#
#  id                :bigint           not null, primary key
#  last_reminded_on  :date
#  timezone          :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  channel_id        :string           not null
#  discord_server_id :string           not null
#
# Indexes
#
#  index_automated_tournament_schedules_on_discord_server_id  (discord_server_id) UNIQUE
#
class AutomatedTournamentSchedule < ApplicationRecord
  enum :timezone, { a: 'a', b: 'b', c: 'c' }

  validates :discord_server_id, presence: true, uniqueness: true
  validates :channel_id, presence: true

  # Day-of-week (Date#wday, Sunday=0..Saturday=6) -> the day's 3 UTC start
  # hours, earliest to latest, matching the real AT schedule.
  WEEKLY_TIMES = {
    0 => [2, 11, 18],  # Sunday
    1 => [4, 13, 20],  # Monday
    2 => [3, 12, 19],  # Tuesday
    3 => [2, 11, 18],  # Wednesday
    4 => [3, 12, 19],  # Thursday
    5 => [4, 13, 20],  # Friday
    6 => [3, 12, 19]   # Saturday
  }.freeze

  TIMEZONE_INDEX = { 'a' => 0, 'b' => 1, 'c' => 2 }.freeze

  # Earliest occurrence T such that `from` is less than `T + 2.hours`. Holds
  # an occurrence for 2 hours after its start (grace period) before
  # advancing to the next day's — so this can return a start time up to 2
  # hours in the past as well as one still in the future.
  def next_occurrence(from: Time.now.utc)
    candidate_date = from.to_date - 1
    loop do
      candidate = occurrence_on(candidate_date)
      return candidate if from < candidate + 2.hours

      candidate_date += 1
    end
  end

  # The occurrence immediately before next_occurrence(from) (one schedule
  # day earlier).
  def previous_occurrence(from: Time.now.utc)
    occurrence_on(next_occurrence(from: from).to_date - 1)
  end

  # Upper edge of the current registration window: the point at which the
  # queue rolls over to build towards the *following* occurrence.
  def window_boundary(from: Time.now.utc)
    next_occurrence(from: from) + 2.hours
  end

  private

  def occurrence_on(date)
    hour = WEEKLY_TIMES.fetch(date.wday)[TIMEZONE_INDEX.fetch(timezone)]
    Time.utc(date.year, date.month, date.day, hour)
  end
end
