require "test_helper"

module DiscordBot
  module Commands
    class PlayerCommandsTest < ActiveSupport::TestCase
      test "register sets the player's igname and confirms it" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :register, user: discord_user, options: { "igname" => "Foo Bar" }
        )

        PlayerCommands.new(nil).dispatch(event)

        player = Player.find_by(provider: "discord", uid: "111")
        assert_equal "Foo Bar", player.igname
        assert_match(/your in-game name is now \*\*Foo Bar\*\*/, event.responses.first[:content])
      end

      test "igname looks up another player's registered name by discord user" do
        create_player(uid: "222", provider: "discord", igname: "Known Name")
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :igname, user: discord_user, options: { "member" => "222" }
        )

        PlayerCommands.new(nil).dispatch(event)

        assert_match(/\*\*Known Name\*\*/, event.responses.first[:content])
      end

      test "igname reports not found when the target player has no igname on file" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :igname, user: discord_user, options: { "member" => "999" }
        )

        PlayerCommands.new(nil).dispatch(event)

        assert_match(/in-game name not found/, event.responses.first[:content])
      end

      test "claim creates and claims a brand new character" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :claim, user: discord_user, options: { "igname" => "brand new hero" }
        )

        PlayerCommands.new(nil).dispatch(event)

        player = Player.find_by(provider: "discord", uid: "111")
        character = Character.find_by(igname: "Brand New Hero")
        assert_equal player, character.player
        assert_match(/successfully created and claimed/, event.responses.first[:content])
      end

      test "claim on an existing unclaimed character links it to the player" do
        character = Character.create!(igname: "Existing Hero")
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: :claim, user: discord_user, options: { "igname" => "existing hero" }
        )

        PlayerCommands.new(nil).dispatch(event)

        assert_equal Player.find_by(provider: "discord", uid: "111"), character.reload.player
        assert_match(/successfully claimed/, event.responses.first[:content])
      end
    end
  end
end
