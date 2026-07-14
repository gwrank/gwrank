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

      test "a valid pawned2 export posts a public embed with one field per player" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => VALID_TEAM_CODE }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        assert_equal 1, event.responses.size
        response = event.responses.first
        assert_nil response[:ephemeral]

        embed = response[:embeds].first
        assert_equal "Team Build", embed[:title]
        assert_equal 8, embed[:fields].size
        assert_equal "1. Paragon / Mesmer", embed[:fields][0][:name]
        assert_match(/Resurrection Signet/, embed[:fields][0][:value])
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

      test "an empty or malformed skill slot shows a placeholder instead of crashing" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => two_slot_pwnd_text }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds].first
        assert_equal 2, embed[:fields].size
        assert_equal "(empty slot)", embed[:fields][0][:value]
        assert_equal "(couldn't decode)", embed[:fields][1][:value]
      end

      test "a slot with no profession and no player but a slot name has no leading space" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => slot_name_only_pwnd_text }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds].first
        assert_equal "1. (Sub)", embed[:fields][0][:name]
      end

      test "a pawned2 export with more than 8 records only renders 8 fields" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => ten_blank_entries_pwnd_text }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds].first
        assert_equal 8, embed[:fields].size
      end

      test "a slot name longer than the truncation limit gets truncated in the field name" do
        discord_user = DiscordBot::Test::FakeDiscordUser.new(111, "Cyril")
        event = DiscordBot::Test::FakeApplicationCommandEvent.new(
          subcommand: nil, user: discord_user, options: { "code" => long_slot_name_pwnd_text }
        )

        TeamBuildCommands.new(nil).dispatch(event)

        embed = event.responses.first[:embeds].first
        name = embed[:fields][0][:name]
        refute_match(/A{51,}/, name)
        assert_operator name.length, :<, 100
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

      # 10 minimal blank-skill entries, to prove the embed caps at 8 fields
      # even when a (possibly crafted/corrupted) export carries more.
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
      # past TeamBuildCommands::NAME_PART_LIMIT), to prove the field name
      # gets truncated rather than carrying the full text into the embed.
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
