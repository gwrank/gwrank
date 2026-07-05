require "test_helper"

module DiscordBot
  module Commands
    class QueueCommandsTest < ActiveSupport::TestCase
      test "players lists current queue registrations in order" do
        p1 = create_player(uid: "1", provider: "discord", igname: "Alice")
        p2 = create_player(uid: "2", provider: "discord", igname: "Bob")
        p1.registrations.create(registered_at: 2.minutes.ago)
        p2.registrations.create(registered_at: 1.minute.ago)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :players, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod")
        )
        QueueCommands.new(nil).dispatch(event)

        content = event.responses.first[:content]
        assert_match(/#1 <@1> \(\*\*Alice\*\*\)/, content)
        assert_match(/#2 <@2> \(\*\*Bob\*\*\)/, content)
      end

      test "reset rejects non-moderators with an ephemeral message and makes no changes" do
        player = create_player(uid: "1", provider: "discord")
        player.registrations.create(registered_at: 1.minute.ago)
        create_player(uid: "999", provider: "discord", is_moderator: false)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :reset, user: DiscordBot::Test::FakeDiscordUser.new(999, "NotAMod")
        )
        QueueCommands.new(nil).dispatch(event)

        assert_equal true, event.responses.first[:ephemeral]
        assert_match(/need to be a moderator/, event.responses.first[:content])
        assert player.reload.has_current_registration?
      end

      test "reset clears the current queue for moderators" do
        player = create_player(uid: "1", provider: "discord")
        player.registrations.create(registered_at: 1.minute.ago)
        create_player(uid: "999", provider: "discord", is_moderator: true)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :reset, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod")
        )
        QueueCommands.new(nil).dispatch(event)

        assert_not player.reload.has_current_registration?
        assert_match(/successfully reset/, event.responses.first[:content])
      end
    end
  end
end
