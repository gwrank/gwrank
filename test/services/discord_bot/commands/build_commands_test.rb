require "test_helper"

module DiscordBot
  module Commands
    class BuildCommandsTest < ActiveSupport::TestCase
      VALID_CODE = "OQYTgmILZipQA4cQr4nQqoScvCA".freeze

      test "a valid code with no verbose option posts a build without attributes or skill fields" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )

        BuildCommands.new(nil).dispatch(event)

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert_nil response[:ephemeral]

        embed = response[:embeds].first
        assert_equal "Warrior / Elementalist", embed[:title]
        assert_nil embed[:description]
        assert_predicate embed[:fields], :blank?
        assert_equal VALID_CODE, embed[:footer][:text]
        assert_equal 1, response[:attachments].size
      end

      test "verbose:true includes attribute ranks and skill name/description fields" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE, "verbose" => true }
        )

        BuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds].first
        assert_match(/\*\*Strength\*\* 12/, embed[:description])
        assert_equal 8, embed[:fields].size
        assert_equal "1. Bull's Strike ⚡5 🔄10", embed[:fields][0][:name]
        assert_match(/\A2\. Resurrection Signet/, embed[:fields][1][:name])
        refute_nil embed[:fields][0][:value]
      end

      test "an invalid code responds ephemerally with a single error, no embed" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => "not a valid code!!" }
        )

        BuildCommands.new(nil).dispatch(event)

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert response[:ephemeral]
        assert_match(/doesn't look like a valid/, response[:content])
      end

      test "an unexpected rendering failure responds ephemerally with a generic error" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )

        GW::SkillStripImage.stub(:build_grid, ->(*) { raise "boom" }) do
          BuildCommands.new(nil).dispatch(event)
        end

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert response[:ephemeral]
        assert_match(/Something went wrong rendering that build/, response[:content])
      end

      test "a valid code defaults to saving a private build owned by the discord user, confirmed ephemerally" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )

        BuildCommands.new(nil).dispatch(event)

        player = Player.find_by(provider: "discord", uid: "111")
        build = player.teambuilds.sole
        assert_equal "private", build.visibility
        assert_equal 1, build.teambuild_characters.size

        followup = event.followups.sole
        assert followup[:ephemeral]
        assert_match(/saved to your account as \*\*private\*\*/, followup[:content])
        assert_match(/\[View build\]\(/, followup[:content])
      end

      test "visibility public makes the saved build publicly visible and confirms it" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user,
          options: { "code" => VALID_CODE, "visibility" => "public" }
        )

        BuildCommands.new(nil).dispatch(event)

        build = Player.find_by(provider: "discord", uid: "111").teambuilds.sole
        assert_equal "public", build.visibility
        assert_includes Teambuild.publicly_visible.ids, build.id
        assert_match(/saved to your account as \*\*public\*\*/, event.followups.sole[:content])
      end

      test "reposting the same code confirms an update instead of creating a duplicate" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        first = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )
        second = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )

        BuildCommands.new(nil).dispatch(first)
        BuildCommands.new(nil).dispatch(second)

        player = Player.find_by(provider: "discord", uid: "111")
        assert_equal 1, player.teambuilds.count
        assert_match(/saved to your account/, first.followups.sole[:content])
        assert_match(/updated in your account/, second.followups.sole[:content])
      end

      test "an invalid code saves nothing" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => "not a valid code!!" }
        )

        BuildCommands.new(nil).dispatch(event)

        assert_equal 0, Teambuild.count
        assert_empty event.followups
      end

      test "a save failure still posts the embed and warns ephemerally" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )
        failure = Teambuilds::Ingest::Result.new(false, nil, [{ "message" => "nope" }], false, false, false)

        Teambuilds::Ingest.stub(:call, failure) do
          BuildCommands.new(nil).dispatch(event)
        end

        assert_equal 1, event.responses.size # embed was posted
        assert_equal 0, Teambuild.count
        assert_match(/couldn't save it: nope/, event.followups.sole[:content])
        assert event.followups.sole[:ephemeral]
      end

      test "an unexpected save error still leaves the embed posted and answers ephemerally" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_CODE }
        )

        DiscordBot::FindOrCreatePlayer.stub(:call, ->(*) { raise "boom" }) do
          BuildCommands.new(nil).dispatch(event)
        end

        assert_equal 1, event.responses.size
        assert_match(/couldn't save it right now/, event.followups.sole[:content])
        assert event.followups.sole[:ephemeral]
      end
    end
  end
end
