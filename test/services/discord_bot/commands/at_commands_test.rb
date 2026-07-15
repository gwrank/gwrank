require "test_helper"

module DiscordBot
  module Commands
    class AtCommandsTest < ActiveSupport::TestCase
      test "players lists current AT queue registrations in order" do
        AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
        p1 = create_player(uid: "1", provider: "discord", igname: "Alice")
        p2 = create_player(uid: "2", provider: "discord", igname: "Bob")
        AutomatedTournamentRegistration.create!(player: p1, discord_server_id: "server-1", registered_at: 2.minutes.ago)
        AutomatedTournamentRegistration.create!(player: p2, discord_server_id: "server-1", registered_at: 1.minute.ago)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :players, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)

        content = event.responses.first[:content]
        assert_match(/#1 <@1> \(\*\*Alice\*\*\)/, content)
        assert_match(/#2 <@2> \(\*\*Bob\*\*\)/, content)
      end

      test "schedule sets the server's AT slot and reminder channel" do
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :schedule, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone"),
          options: { "timezone" => "b" }, channel_id: "chan-1"
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)

        schedule = AutomatedTournamentSchedule.find_by(discord_server_id: "server-1")
        assert_equal "b", schedule.timezone
        assert_equal "chan-1", schedule.channel_id
        assert_match(/tracks AT slot \*\*b\*\*/, event.responses.first[:content])
      end

      test "schedule resets last_reminded_on when the timezone changes" do
        AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "a", channel_id: "chan-1", last_reminded_on: Date.current)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :schedule, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone"),
          options: { "timezone" => "b" }, channel_id: "chan-2"
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)

        schedule = AutomatedTournamentSchedule.find_by(discord_server_id: "server-1")
        assert_equal "b", schedule.timezone
        assert_nil schedule.last_reminded_on
      end

      test "schedule keeps last_reminded_on when re-run with the same timezone" do
        today = Date.current
        AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1", last_reminded_on: today)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :schedule, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone"),
          options: { "timezone" => "b" }, channel_id: "chan-2"
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)

        schedule = AutomatedTournamentSchedule.find_by(discord_server_id: "server-1")
        assert_equal "chan-2", schedule.channel_id
        assert_equal today, schedule.last_reminded_on
      end

      test "next shows time remaining when the AT hasn't started yet" do
        schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
        next_occ = schedule.next_occurrence

        travel_to(next_occ - 3.hours) do
          event = DiscordBot::Test::FakeApplicationCommandEvent.new(
            subcommand: :next, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
          )
          def event.server
            Struct.new(:id).new("server-1")
          end

          AtCommands.new(nil).dispatch(event)
          assert_match(/starts in 3h 0m/, event.responses.first[:content])
        end
      end

      test "next shows the registration window status once the AT has started" do
        schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
        next_occ = schedule.next_occurrence

        travel_to(next_occ + 1.hour) do
          event = DiscordBot::Test::FakeApplicationCommandEvent.new(
            subcommand: :next, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
          )
          def event.server
            Struct.new(:id).new("server-1")
          end

          AtCommands.new(nil).dispatch(event)
          content = event.responses.first[:content]
          assert_match(/started 1h 0m ago/, content)
          assert_match(/closes in 1h 0m/, content)
        end
      end

      test "next tells the player to set a schedule first when none exists" do
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :next, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)
        assert_match(/run .?\/at schedule.? first/i, event.responses.first[:content])
      end

      test "join tells the player to set a schedule first when none exists" do
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :join, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)
        assert_match(/run .?\/at schedule.? first/i, event.responses.first[:content])
        assert_nil event.responses.first[:has_components]
      end

      test "players tells the player to set a schedule first when none exists" do
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :players, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
        )
        def event.server
          Struct.new(:id).new("server-1")
        end

        AtCommands.new(nil).dispatch(event)
        assert_match(/run .?\/at schedule.? first/i, event.responses.first[:content])
      end
    end
  end
end
