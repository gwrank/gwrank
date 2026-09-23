# == Schema Information
#
# Table name: automated_tournament_schedules
#
#  id                             :bigint           not null, primary key
#  is_monthly                     :boolean          default(FALSE), not null
#  last_registration_reminded_for :date
#  last_reminded_on               :date
#  recurrence_pattern             :string
#  registration_opens_days_before :integer          default(28)
#  timezone                       :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  channel_id                     :string           not null
#  discord_server_id              :string           not null
#
# Indexes
#
#  index_at_schedules_on_server_and_monthly  (discord_server_id,is_monthly) UNIQUE
#
class AutomatedTournamentSchedule < ApplicationRecord
  enum :timezone, { a: 'a', b: 'b', c: 'c' }

  scope :daily, -> { where(is_monthly: false) }
  scope :monthly, -> { where(is_monthly: true) }

  validates :discord_server_id, presence: true, uniqueness: { scope: :is_monthly }
  validates :channel_id, presence: true
  validates :timezone, presence: true, unless: :is_monthly?
  validates :recurrence_pattern, inclusion: { in: %w[daily_a daily_b daily_c every_3rd_saturday] }, allow_nil: true
  
  before_validation :set_default_recurrence_pattern, on: :create
  
  def set_default_recurrence_pattern
    self.recurrence_pattern ||= "daily_#{timezone}" if timezone.present?
  end
  
  def daily_a?
    recurrence_pattern == 'daily_a'
  end
  
  def daily_b?
    recurrence_pattern == 'daily_b'
  end
  
  def daily_c?
    recurrence_pattern == 'daily_c'
  end
  
  def every_3rd_saturday?
    recurrence_pattern == 'every_3rd_saturday'
  end

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
    if is_monthly?
      next_monthly_occurrence(from)
    else
      candidate_date = from.to_date - 1
      loop do
        candidate = occurrence_on(candidate_date)
        return candidate if from < candidate + 2.hours

        candidate_date += 1
      end
    end
  end

  def next_daily_occurrence(from)
    now = from
    timezone_letter = timezone
    
    at_times = {
      'a' => { hour: 15, min: 0 },
      'b' => { hour: 18, min: 0 },
      'c' => { hour: 21, min: 0 }
    }
    
    target_time = at_times[timezone_letter]
    target_today = now.change(hour: target_time[:hour], min: target_time[:min], sec: 0)
    
    if now <= target_today
      target_today
    else
      target_today + 1.day
    end
  end

  # The occurrence immediately before next_occurrence(from) (one schedule
  # day earlier for daily, one month earlier for monthly).
  def previous_occurrence(from: Time.now.utc)
    if is_monthly?
      ref = next_monthly_occurrence(from) - 1.month
      monthly_occurrence_at(ref.year, ref.month)
    else
      occurrence_on(next_occurrence(from: from).to_date - 1)
    end
  end

  # Upper edge of the current registration window: the point at which the
  # queue rolls over to build towards the *following* occurrence.
  def window_boundary(from: Time.now.utc)
    next_occurrence(from: from) + 2.hours
  end

  # Monthly tournaments happen on the 3rd Saturday of each month. Only the
  # date is announced (no fixed hour), so occurrences are midnight UTC.
  # Adjust MONTHLY_OCCURRENCE_HOUR_UTC once a real hour is confirmed.
  MONTHLY_OCCURRENCE_HOUR_UTC = 0

  def next_monthly_occurrence(from)
    now = from
    candidate = monthly_occurrence_at(now.year, now.month)
    return candidate if now <= candidate

    following = now + 1.month
    monthly_occurrence_at(following.year, following.month)
  end

  def monthly_occurrence_at(year, month)
    date = find_nth_weekday(year, month, 6, 3)
    Time.utc(date.year, date.month, date.day, MONTHLY_OCCURRENCE_HOUR_UTC)
  end

  def find_nth_weekday(year, month, weekday, nth)
    first_day = Date.new(year, month, 1)
    first_weekday = first_day + ((weekday - first_day.wday + 7) % 7).days
    first_weekday + (nth - 1).weeks
  end

  def registration_window_open?(from: Time.now.utc)
    if is_monthly?
      next_occ = next_occurrence(from: from)
      registration_start = next_occ - registration_opens_days_before.days
      from >= registration_start && from <= next_occ
    else
      now = from
      next_occ = next_occurrence(from: now)
      boundary = window_boundary(from: now)
      now >= boundary - 30.minutes && now <= next_occ
    end
  end

  private

  def occurrence_on(date)
    hour = WEEKLY_TIMES.fetch(date.wday)[TIMEZONE_INDEX.fetch(timezone)]
    Time.utc(date.year, date.month, date.day, hour)
  end
end
