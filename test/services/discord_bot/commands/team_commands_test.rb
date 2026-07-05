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

      test "new rejects non-moderators" do
        create_player(uid: "999", provider: "discord", is_moderator: false)
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :new, user: DiscordBot::Test::FakeDiscordUser.new(999, "NotAMod")
        )

        TeamCommands.new(nil).dispatch(event)

        assert_match(/need to be a moderator/, event.responses.first[:content])
      end

      test "new reports how many more players are needed when the queue isn't full" do
        create_player(uid: "999", provider: "discord", is_moderator: true)
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :new, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod")
        )

        TeamCommands.new(nil).dispatch(event)

        assert_match(/need exactly 16 players/, event.responses.first[:content])
      end

      test "new responds via event.respond (not only channel.send_message) when teams form successfully" do
        create_player(uid: "999", provider: "discord", is_moderator: true)
        players = Array.new(16) { create_player(elo_rating: 1200) }
        players.each { |p| p.registrations.create(registered_at: 1.minute.ago) }

        # team_players uses .includes(:player, :profession), an ActiveRecord::Relation
        # method - a plain Array doesn't respond to it, so the double needs to.
        empty_team_players = Struct.new(:records) { def includes(*) = records }.new([])
        fake_team = Struct.new(:players, :team_players).new(players.first(8), empty_team_players)
        fake_scrim = Struct.new(:team_a, :team_b, :captain_a_id, :captain_b_id).new(
          fake_team, fake_team, nil, nil
        )

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :new, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod")
        )

        Scrims::FormTeams.stub(:call!, fake_scrim) do
          TeamCommands.new(nil).dispatch(event)
        end

        assert_equal 1, event.responses.size
        assert_match(/Team A/, event.responses.first[:content])
      end
    end
  end
end
