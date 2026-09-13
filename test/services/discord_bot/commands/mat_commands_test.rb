require "test_helper"

module DiscordBot
  module Commands
    class MatCommandsTest < ActiveSupport::TestCase
      def schedule_event(server_id:, pattern: "every_3rd_saturday", channel_id: "mat-chan")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :schedule,
          user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone"),
          options: { "pattern" => pattern },
          channel_id: channel_id
        )
        sid = server_id
        event.define_singleton_method(:server) { Struct.new(:id).new(sid) }
        event
      end

      test "schedule creates a monthly schedule alongside an existing daily schedule" do
        AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")

        MatCommands.new(nil).dispatch(schedule_event(server_id: "server-1"))

        daily = AutomatedTournamentSchedule.find_by(discord_server_id: "server-1", is_monthly: false)
        monthly = AutomatedTournamentSchedule.find_by(discord_server_id: "server-1", is_monthly: true)
        assert_not_nil daily, "daily schedule must survive /mat schedule"
        assert_equal "b", daily.timezone
        assert_not_nil monthly, "monthly schedule must be created"
        assert_equal "every_3rd_saturday", monthly.recurrence_pattern
        assert_equal "mat-chan", monthly.channel_id
      end

      test "schedule works when the server has no schedule yet" do
        event = schedule_event(server_id: "server-new")

        MatCommands.new(nil).dispatch(event)

        monthly = AutomatedTournamentSchedule.find_by(discord_server_id: "server-new", is_monthly: true)
        assert_not_nil monthly
        assert_match(/every_3rd_saturday/, event.responses.first[:content])
      end

      test "daily schedule lookup still finds the daily row once a monthly row exists" do
        AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
        MatCommands.new(nil).dispatch(schedule_event(server_id: "server-1"))

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :next, user: DiscordBot::Test::FakeDiscordUser.new(999, "Someone")
        )
        event.define_singleton_method(:server) { Struct.new(:id).new("server-1") }

        AtCommands.new(nil).dispatch(event)

        assert_match(/slot B/i, event.responses.first[:content])
      end
    end
  end
end
