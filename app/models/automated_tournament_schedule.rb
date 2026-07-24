# == Schema Information
#
# Table name: automated_tournament_schedules
#
#  id                             :bigint           not null, primary key
#  is_monthly                     :boolean          default(FALSE)
#  last_reminded_on               :date
#  recurrence_pattern             :string
#  registration_opens_days_before :integer          default(28)
#  timezone                       :string           not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  channel_id                     :string           not null
#  discord_server_id              :string           not null
#
# Indexes
#
#  index_automated_tournament_schedules_on_discord_server_id  (discord_server_id) UNIQUE
#
class AutomatedTournamentSchedule < ApplicationRecord
  enum :timezone, { a: 'a', b: 'b', c: 'c' }

  validates :discord_server_id, presence: true, uniqueness: true
  validates :channel_id, presence: true
  validates :timezone, presence: true
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
  # day earlier).
  def previous_occurrence(from: Time.now.utc)
    occurrence_on(next_occurrence(from: from).to_date - 1)
  end

  # Upper edge of the current registration window: the point at which the
  # queue rolls over to build towards the *following* occurrence.
  def window_boundary(from: Time.now.utc)
    next_occurrence(from: from) + 2.hours
  end

  def next_monthly_occurrence(from)
    now = from
    
    current_year = now.year
    current_month = now.month
    
    third_saturday = find_nth_weekday(current_year, current_month, 6, 3)
    
    if now <= third_saturday
      return third_saturday
    end
    
    next_month = now + 1.month
    find_nth_weekday(next_month.year, next_month.month, 6, 3)
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
