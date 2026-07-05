require "test_helper"

module DiscordBot
  module Commands
    class TeamCommandsTest < ActiveSupport::TestCase
      test "captains reports no active captains when there's no current scrim" do
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :captains, user: DiscordBot::Test::FakeDiscordUser.new(1, "Someone")
        )
        TeamCommands.new(nil).dispatch(event)

        assert_match(/no active scrim captains/, event.responses.first[:content])
      end

      test "roll responds with a number between 0 and 100" do
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :roll, user: DiscordBot::Test::FakeDiscordUser.new(1, "Someone")
        )
        TeamCommands.new(nil).dispatch(event)

        assert_match(/you rolled: \d{1,3}/, event.responses.first[:content])
      end
    end
  end
end
