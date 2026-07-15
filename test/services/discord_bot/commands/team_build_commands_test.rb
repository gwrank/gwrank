require "test_helper"

module DiscordBot
  module Commands
    class TeamBuildCommandsTest < ActiveSupport::TestCase
      VALID_TEAM_CODE = <<~PWND.freeze
        pwnd0001?download pawned2 @ memorial.redeemer.biz | Copyright 2008-2018 Redeemer
        >ZOQWjUyoogOXgiQPYBzgdwubBAAAAAAAACCgbOQSkcMo5ZWyj9WD7hXwPYHs7+TAAAAAAAACCgbOQOk
        UyP1JimDnWD7hXwWYHs7WAAAAAAAAACCgUOAeAMY7LX304uMlmjzJIAAAAAAACCgVOAeAQYbXOUOGXLT
        STciTQAAAAAAACCgUOAeAMBzqJz8s9NLnR7JIAAAAAAACCgUOwoAMW67W9QgcSm+3E1LAAAAAAACCgVO
        wcAQEENgaRCErETfVETQAAAAAAACCg<
      PWND

      test "a valid pawned2 export with no verbose option posts one compact embed with a grid image and codes" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_TEAM_CODE }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert_nil response[:ephemeral]
        assert_equal 1, response[:embeds].size
        assert_equal 1, response[:attachments].size

        embed = response[:embeds][0]
        assert_equal "Team Build (8 players)", embed[:title]
        assert_match(%r{\Aattachment://}, embed[:image][:url])
        lines = embed[:description].split("\n")
        assert_equal 8, lines.size
        assert_equal "1. Paragon / Mesmer: `OQWjUyoogOXgiQPYBzgdwubBA`", lines[0]
      end

      test "verbose:true posts one embed per player, each with its own image, attributes, and skill names" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_TEAM_CODE, "verbose" => true }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert_nil response[:ephemeral]
        assert_equal 8, response[:embeds].size
        assert_equal 8, response[:attachments].size

        embed = response[:embeds][0]
        assert_equal "1. Paragon / Mesmer", embed[:title]
        assert_match(/\*\*.+\*\*/, embed[:description])
        assert_match(%r{\Aattachment://}, embed[:image][:url])
        assert_equal "Skills", embed[:fields][0][:name]
        assert_match(/Resurrection Signet/, embed[:fields][0][:value])
        assert_equal "OQWjUyoogOXgiQPYBzgdwubBA", embed[:footer][:text]
      end

      test "an invalid pawned2 export responds ephemerally with a single error, no embed" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => "not a pawned2 export" }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert response[:ephemeral]
        assert_match(/doesn't look like a valid pawned2/, response[:content])
      end

      test "an empty or malformed skill slot shows as a placeholder line in the compact view" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => two_slot_pwnd_text }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds][0]
        lines = embed[:description].split("\n")
        assert_equal 2, lines.size
        assert_match(/_\(empty slot\)_/, lines[0])
        assert_match(/_\(couldn't decode\)_/, lines[1])
      end

      test "an empty or malformed skill slot shows a placeholder embed with no image in verbose mode" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => two_slot_pwnd_text, "verbose" => true }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        response = event.responses.first
        assert_equal 2, response[:embeds].size
        assert_equal 0, response[:attachments].size
        assert_equal "(empty slot)", response[:embeds][0][:description]
        assert_nil response[:embeds][0][:image]
        assert_equal "(couldn't decode)", response[:embeds][1][:description]
        assert_nil response[:embeds][1][:image]
      end

      test "a slot with no profession and no player but a slot name has no leading space" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => slot_name_only_pwnd_text, "verbose" => true }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds][0]
        assert_equal "1. (Sub)", embed[:title]
      end

      test "a pawned2 export with more than 8 records only renders 8 rows in the compact view" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => ten_blank_entries_pwnd_text }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        response = event.responses.first
        assert_equal 1, response[:embeds].size
        assert_equal 8, response[:embeds][0][:description].split("\n").size
      end

      test "a pawned2 export with more than 8 records only renders 8 embeds in verbose mode" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => ten_blank_entries_pwnd_text, "verbose" => true }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        response = event.responses.first
        assert_equal 8, response[:embeds].size
      end

      test "a slot name longer than the truncation limit gets truncated in the embed title" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => long_slot_name_pwnd_text, "verbose" => true }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds][0]
        refute_match(/A{51,}/, embed[:title])
        assert_operator embed[:title].length, :<, 100
      end

      private

      # Build 1 has a blank skills field (unfilled roster slot). Build 2
      # has a skills field that decodes cleanly at the bit level but fails
      # GW::TemplateReader.decode!'s strict validation (primary profession
      # "None" — same fixture code /build's own test suite uses for this).
      def two_slot_pwnd_text
        base64_chr = ->(n) { GW::TemplateReader::Base64Map[n] }
        build = lambda do |skills|
          payload = +""
          payload << base64_chr.call(skills.length) << skills
          payload << base64_chr.call(0) # equipment
          3.times { payload << base64_chr.call(0) } # weaponsets
          payload << base64_chr.call(0) # flags
          payload << base64_chr.call(0) # player, 0-length
          payload << base64_chr.call(0) << base64_chr.call(0) # description, 0-length
          payload
        end

        none_primary_code = "OAAAAAAAAAAAAAAA"
        payload = build.call("") + build.call(none_primary_code)
        "pwnd0001?download pawned2 @ memorial.redeemer.biz\n>#{payload}<"
      end

      # A single entry with a blank skills field (unfilled), no player, but
      # a slot name set — the combination that previously produced a
      # leading-space field name ("1.  (Sub)") instead of "1. (Sub)".
      def slot_name_only_pwnd_text
        base64_chr = ->(n) { GW::TemplateReader::Base64Map[n] }
        encoded_slot_name = Base64.strict_encode64("Sub")

        payload = +""
        payload << base64_chr.call(0) # skills, 0-length
        payload << base64_chr.call(0) # equipment
        3.times { payload << base64_chr.call(0) } # weaponsets
        payload << base64_chr.call(0) # flags
        payload << base64_chr.call(0) # player, 0-length
        payload << base64_chr.call(encoded_slot_name.length / 64)
        payload << base64_chr.call(encoded_slot_name.length % 64)
        payload << encoded_slot_name

        "pwnd0001?download pawned2 @ memorial.redeemer.biz\n>#{payload}<"
      end

      # 10 minimal blank-skill entries, to prove the response caps at 8
      # embeds even when a (possibly crafted/corrupted) export carries more.
      def ten_blank_entries_pwnd_text
        base64_chr = ->(n) { GW::TemplateReader::Base64Map[n] }
        blank_entry = lambda do
          payload = +""
          payload << base64_chr.call(0) # skills, 0-length
          payload << base64_chr.call(0) # equipment
          3.times { payload << base64_chr.call(0) } # weaponsets
          payload << base64_chr.call(0) # flags
          payload << base64_chr.call(0) # player, 0-length
          payload << base64_chr.call(0) << base64_chr.call(0) # description, 0-length
          payload
        end

        payload = 10.times.map { blank_entry.call }.join
        "pwnd0001?download pawned2 @ memorial.redeemer.biz\n>#{payload}<"
      end

      # A single entry whose slot name decodes to 80 characters (comfortably
      # past TeamBuildCommands::NAME_PART_LIMIT), to prove the embed title
      # gets truncated rather than carrying the full text.
      def long_slot_name_pwnd_text
        base64_chr = ->(n) { GW::TemplateReader::Base64Map[n] }
        encoded_slot_name = Base64.strict_encode64("A" * 80)

        payload = +""
        payload << base64_chr.call(0) # skills, 0-length
        payload << base64_chr.call(0) # equipment
        3.times { payload << base64_chr.call(0) } # weaponsets
        payload << base64_chr.call(0) # flags
        payload << base64_chr.call(0) # player, 0-length
        payload << base64_chr.call(encoded_slot_name.length / 64)
        payload << base64_chr.call(encoded_slot_name.length % 64)
        payload << encoded_slot_name

        "pwnd0001?download pawned2 @ memorial.redeemer.biz\n>#{payload}<"
      end
    end
  end
end
