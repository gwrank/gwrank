require "test_helper"

module DiscordBot
  module Commands
    class AtCommandsTest < ActiveSupport::TestCase
      test "players lists current AT queue registrations in order" do
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
    end
  end
end
