require "test_helper"

class AutomatedTournamentRegistrationTest < ActiveSupport::TestCase
  test "current_for_server is empty when the server has no schedule" do
    player = create_player(uid: "1", provider: "discord")
    AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: 1.minute.ago)

    assert_empty AutomatedTournamentRegistration.current_for_server("server-1")
  end

  test "current_for_server includes a registration made during the current window" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence

    travel_to(next_occ - 1.hour) do
      player = create_player(uid: "1", provider: "discord")
      registration = AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: Time.now.utc)

      assert_includes AutomatedTournamentRegistration.current_for_server("server-1"), registration
    end
  end

  test "current_for_server excludes a registration from before the previous rollover" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence
    stale_registered_at = schedule.previous_occurrence(from: next_occ) + 1.hour # before previous window's own boundary

    player = create_player(uid: "1", provider: "discord")
    registration = AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: stale_registered_at)

    travel_to(next_occ - 1.hour) do
      assert_not_includes AutomatedTournamentRegistration.current_for_server("server-1"), registration
    end
  end

  test "current_for_server excludes a registration registered exactly at the lower bound" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence

    travel_to(next_occ - 1.hour) do
      lower_bound = schedule.previous_occurrence(from: Time.now.utc) + 2.hours
      player = create_player(uid: "1", provider: "discord")
      registration = AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: lower_bound)

      assert_not_includes AutomatedTournamentRegistration.current_for_server("server-1"), registration
    end
  end

  test "current_for_server includes a registration registered exactly at the upper bound" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence

    travel_to(next_occ - 1.hour) do
      upper_bound = schedule.window_boundary(from: Time.now.utc)
      player = create_player(uid: "1", provider: "discord")
      registration = AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: upper_bound)

      assert_includes AutomatedTournamentRegistration.current_for_server("server-1"), registration
    end
  end

  test "current_for_server excludes an unregistered player even inside the window" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence

    travel_to(next_occ - 1.hour) do
      player = create_player(uid: "1", provider: "discord")
      AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: Time.now.utc, unregistered_at: Time.now.utc)

      assert_empty AutomatedTournamentRegistration.current_for_server("server-1")
    end
  end

  test "in_at_queue? matches current_for_server's predicate for a single registration" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence

    travel_to(next_occ - 1.hour) do
      player = create_player(uid: "1", provider: "discord")
      registration = AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: Time.now.utc)

      assert registration.in_at_queue?("server-1")
    end
  end

  test "in_at_queue? is false once now crosses the window boundary" do
    schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
    next_occ = schedule.next_occurrence
    player = create_player(uid: "1", provider: "discord")
    registration = nil

    travel_to(next_occ - 1.hour) do
      registration = AutomatedTournamentRegistration.create!(player: player, discord_server_id: "server-1", registered_at: Time.now.utc)
    end

    travel_to(schedule.window_boundary(from: next_occ) + 1.minute) do
      assert_not registration.in_at_queue?("server-1")
    end
  end
end
