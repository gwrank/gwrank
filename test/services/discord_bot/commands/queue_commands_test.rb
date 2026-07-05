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

      test "add puts a known player in the queue" do
        create_player(uid: "1", provider: "discord", igname: "Alice")
        create_player(uid: "999", provider: "discord", is_moderator: true)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :add, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod"), options: { "igname" => "Alice" }
        )
        QueueCommands.new(nil).dispatch(event)

        assert Player.find_by(igname: "Alice").has_current_registration?
      end

      test "add rejects non-moderators" do
        create_player(uid: "1", provider: "discord", igname: "Alice")
        create_player(uid: "999", provider: "discord", is_moderator: false)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :add, user: DiscordBot::Test::FakeDiscordUser.new(999, "NotAMod"), options: { "igname" => "Alice" }
        )
        QueueCommands.new(nil).dispatch(event)

        assert_not Player.find_by(igname: "Alice").has_current_registration?
        assert_match(/need to be a moderator/, event.responses.first[:content])
      end

      test "remove takes a player out of the queue" do
        player = create_player(uid: "1", provider: "discord", igname: "Alice")
        player.registrations.create(registered_at: 1.minute.ago)
        create_player(uid: "999", provider: "discord", is_moderator: true)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :remove, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod"), options: { "igname" => "Alice" }
        )
        QueueCommands.new(nil).dispatch(event)

        assert_not player.reload.has_current_registration?
      end

      test "remove reports an unknown igname" do
        create_player(uid: "999", provider: "discord", is_moderator: true)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :remove, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod"), options: { "igname" => "Nobody" }
        )
        QueueCommands.new(nil).dispatch(event)

        assert_match(/Nobody is not found/, event.responses.first[:content])
      end

      test "afk with no member marks the invoking moderator AFK" do
        mod = create_player(uid: "999", provider: "discord", is_moderator: true)
        mod.registrations.create(registered_at: 1.minute.ago)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :afk, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod")
        )
        QueueCommands.new(nil).dispatch(event)

        assert_not mod.reload.has_current_registration?
        assert mod.has_afk_registration?
        assert_match(/you are now in AFK mode/, event.responses.first[:content])
      end

      test "afk with a member marks that player AFK" do
        target = create_player(uid: "1", provider: "discord", igname: "Alice")
        target.registrations.create(registered_at: 1.minute.ago)
        create_player(uid: "999", provider: "discord", is_moderator: true)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :afk, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod"), options: { "member" => "1" }
        )
        QueueCommands.new(nil).dispatch(event)

        assert target.reload.has_afk_registration?
        assert_match(/Alice is now in AFK mode/, event.responses.first[:content])
      end

      test "back with no member clears the invoking moderator's own AFK status" do
        mod = create_player(uid: "999", provider: "discord", is_moderator: true)
        mod.registrations.create(registered_at: 1.hour.ago, unregistered_at: 30.minutes.ago)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :back, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod")
        )
        QueueCommands.new(nil).dispatch(event)

        assert mod.reload.has_current_registration?
        assert_match(/welcome back/, event.responses.first[:content])
      end

      test "back with a member does not actually clear that player's AFK status (pre-existing bug, preserved intentionally)" do
        target = create_player(uid: "1", provider: "discord", igname: "Alice")
        target.registrations.create(registered_at: 1.hour.ago, unregistered_at: 30.minutes.ago)
        create_player(uid: "999", provider: "discord", is_moderator: true)

        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :back, user: DiscordBot::Test::FakeDiscordUser.new(999, "Mod"), options: { "member" => "1" }
        )
        QueueCommands.new(nil).dispatch(event)

        # BUG (pre-existing, intentionally not fixed by this migration - see handle_back):
        # bringing back someone else re-stamps unregistered_at instead of clearing it,
        # so the player is still AFK, not actually returned to the active queue.
        assert target.reload.has_afk_registration?
        assert_not target.has_current_registration?
        assert_match(/now back in the queue/, event.responses.first[:content])
      end
    end
  end
end
