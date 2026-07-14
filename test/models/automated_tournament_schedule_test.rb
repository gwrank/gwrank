require "test_helper"

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
class AutomatedTournamentScheduleTest < ActiveSupport::TestCase
  test "next_occurrence returns today's occurrence when it hasn't started yet" do
    schedule = AutomatedTournamentSchedule.new(timezone: "b")
    from = Time.utc(2026, 7, 15, 9, 0) # Wednesday, before Wed b (11:00)
    assert_equal Time.utc(2026, 7, 15, 11, 0), schedule.next_occurrence(from: from)
  end

  test "next_occurrence holds the occurrence during its 2 hour grace period" do
    schedule = AutomatedTournamentSchedule.new(timezone: "b")
    from = Time.utc(2026, 7, 15, 12, 30) # 1.5h after Wed b started
    assert_equal Time.utc(2026, 7, 15, 11, 0), schedule.next_occurrence(from: from)
  end

  test "next_occurrence advances to the next day's occurrence once the grace period ends" do
    schedule = AutomatedTournamentSchedule.new(timezone: "b")
    from = Time.utc(2026, 7, 15, 13, 1) # 1 minute past Wed b's 2h grace (11:00 + 2h)
    assert_equal Time.utc(2026, 7, 16, 12, 0), schedule.next_occurrence(from: from) # Thursday b = 12:00
  end

  test "previous_occurrence is one schedule-day before next_occurrence" do
    schedule = AutomatedTournamentSchedule.new(timezone: "b")
    from = Time.utc(2026, 7, 15, 9, 0)
    assert_equal Time.utc(2026, 7, 14, 12, 0), schedule.previous_occurrence(from: from) # Tuesday b = 12:00
  end

  test "window_boundary is 2 hours after next_occurrence" do
    schedule = AutomatedTournamentSchedule.new(timezone: "b")
    from = Time.utc(2026, 7, 15, 9, 0)
    assert_equal Time.utc(2026, 7, 15, 13, 0), schedule.window_boundary(from: from)
  end

  test "a is earlier than b is earlier than c on the same day" do
    from = Time.utc(2026, 7, 15, 0, 30) # Wednesday, just after midnight
    a = AutomatedTournamentSchedule.new(timezone: "a").next_occurrence(from: from)
    b = AutomatedTournamentSchedule.new(timezone: "b").next_occurrence(from: from)
    c = AutomatedTournamentSchedule.new(timezone: "c").next_occurrence(from: from)

    assert_equal Time.utc(2026, 7, 15, 2, 0), a
    assert_equal Time.utc(2026, 7, 15, 11, 0), b
    assert_equal Time.utc(2026, 7, 15, 18, 0), c
    assert a < b
    assert b < c
  end

  test "timezone rejects values outside a/b/c" do
    schedule = AutomatedTournamentSchedule.new(timezone: "a")
    assert_raises(ArgumentError) { schedule.timezone = "z" }
  end

  test "discord_server_id must be unique" do
    AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "a", channel_id: "chan-1")
    dup = AutomatedTournamentSchedule.new(discord_server_id: "server-1", timezone: "b", channel_id: "chan-2")

    assert_not dup.valid?
    assert_includes dup.errors[:discord_server_id], "has already been taken"
  end
end
