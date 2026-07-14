require "test_helper"

module DiscordBot
  module Commands
    class BuildCommandsTest < ActiveSupport::TestCase
      VALID_CODE = "OQYTgmILZipQA4cQr4nQqoScvCA".freeze

      test "a valid code posts a public embed with the build details" do
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
        assert_match(/\*\*Strength\*\* 12/, embed[:description])
        assert_equal 8, embed[:fields].size
        assert_equal "1. Bull's Strike", embed[:fields][0][:name]
        assert_equal "2. Resurrection Signet", embed[:fields][1][:name]
        assert_equal VALID_CODE, embed[:footer][:text]
        assert_equal 2, response[:attachments].size
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

        GW::SkillStripImage.stub(:build, ->(*) { raise "boom" }) do
          BuildCommands.new(nil).dispatch(event)
        end

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert response[:ephemeral]
        assert_match(/Something went wrong rendering that build/, response[:content])
      end
    end
  end
end
