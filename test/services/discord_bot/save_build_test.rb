require "test_helper"

module DiscordBot
  class SaveBuildTest < ActiveSupport::TestCase
    VALID_CODE = "OQYTgmILZipQA4cQr4nQqoScvCA".freeze

    # Same fixture export as TeamBuildCommandsTest: 8 decodable players,
    # first one "P/Me" with code OQWjUyoogOXgiQPYBzgdwubBA.
    VALID_TEAM_CODE = <<~PWND.freeze
      pwnd0001?download pawned2 @ memorial.redeemer.biz | Copyright 2008-2018 Redeemer
      >ZOQWjUyoogOXgiQPYBzgdwubBAAAAAAAACCgbOQSkcMo5ZWyj9WD7hXwPYHs7+TAAAAAAAACCgbOQOk
      UyP1JimDnWD7hXwWYHs7WAAAAAAAAACCgUOAeAMY7LX304uMlmjzJIAAAAAAACCgVOAeAQYbXOUOGXLT
      STciTQAAAAAAACCgUOAeAMBzqJz8s9NLnR7JIAAAAAAACCgUOwoAMW67W9QgcSm+3E1LAAAAAAACCgVO
      wcAQEENgaRCErETfVETQAAAAAAACCg<
    PWND

    setup do
      @player = Player.create!(
        provider: "discord", uid: "42", username: "Cyril",
        email: "save-build-test@gwrank.test", password: "secret123"
      )
    end

    test "a single entry creates a private one-character teambuild mirroring the template reader" do
      entry = SaveBuild::Entry.new(skills_code: VALID_CODE, player: nil, slot_name: nil)

      result = SaveBuild.call(player: @player, entries: [entry])

      assert_predicate result, :ok?
      assert_predicate result, :created?
      teambuild = result.teambuild
      assert_equal "private", teambuild.visibility
      assert_match(Teambuilds::Validator::UUID_RE, teambuild.source_uuid)
      assert_empty Teambuilds::Validator.validate(teambuild.document)

      assert_equal 1, teambuild.teambuild_characters.size
      character = teambuild.document["characters"].sole
      reader = GW::TemplateReader.decode!(VALID_CODE)
      assert_equal reader.primary, character["primaryProfession"]
      assert_equal reader.secondary, character["secondaryProfession"]
      assert_equal reader.skills, character["skillIds"]
      expected_attributes = reader.attributes.map { |(id, points)| { "id" => id, "points" => points } }
      assert_equal expected_attributes, character["attributes"]
    end

    test "a pawned2 export creates one teambuild with name and assignment mapped per entry" do
      entries = GW::PwndTemplate.decode!(VALID_TEAM_CODE)

      result = SaveBuild.call(player: @player, entries: entries, name: "GvG Split")

      assert_predicate result, :ok?
      teambuild = result.teambuild
      assert_equal "GvG Split", teambuild.name
      assert_equal entries.size, teambuild.player_count
      characters = teambuild.document["characters"]
      entries.each_with_index do |entry, index|
        assert_equal entry.player.to_s, characters[index]["name"]
        assert_equal entry.slot_name.to_s, characters[index]["assignment"]
      end
    end

    test "reposting the same codes updates the existing teambuild instead of duplicating" do
      entries = GW::PwndTemplate.decode!(VALID_TEAM_CODE)

      first = SaveBuild.call(player: @player, entries: entries)
      second = SaveBuild.call(player: @player, entries: entries, visibility: "public")

      assert_equal first.teambuild.id, second.teambuild.id
      refute_predicate second, :created?
      assert_equal "public", second.teambuild.reload.visibility
      assert_equal 1, @player.teambuilds.count
    end

    test "two players posting the same codes get distinct builds" do
      other = Player.create!(
        provider: "discord", uid: "43", username: "Ana",
        email: "save-build-other@gwrank.test", password: "secret123"
      )
      entry = SaveBuild::Entry.new(skills_code: VALID_CODE, player: nil, slot_name: nil)

      SaveBuild.call(player: @player, entries: [entry])
      SaveBuild.call(player: other, entries: [entry])

      assert_equal 1, @player.teambuilds.count
      assert_equal 1, other.teambuilds.count
    end

    test "an undecodable entry mid-export does not fail saving the rest" do
      broken_code = "OAAAAAAAAAAAAAAA" # fails TemplateReader strict validation (primary None)
      entries = [
        SaveBuild::Entry.new(skills_code: VALID_CODE, player: nil, slot_name: nil),
        SaveBuild::Entry.new(skills_code: broken_code, player: nil, slot_name: nil),
        SaveBuild::Entry.new(skills_code: "", player: nil, slot_name: nil)
      ]

      result = SaveBuild.call(player: @player, entries: entries)

      assert_predicate result, :ok?
      assert_equal 1, result.teambuild.document["characters"].size
    end

    test "a non-ascii garbage entry does not crash the save and the rest persists" do
      entries = [
        SaveBuild::Entry.new(skills_code: VALID_CODE, player: nil, slot_name: nil),
        SaveBuild::Entry.new(skills_code: "OQYTgmILZipQA4cQr4nQqoScvCé", player: nil, slot_name: nil)
      ]

      result = SaveBuild.call(player: @player, entries: entries)

      assert_predicate result, :ok?
      assert_equal 1, result.teambuild.document["characters"].size
    end

    test "an export with no decodable codes at all fails without persisting anything" do
      entries = [
        SaveBuild::Entry.new(skills_code: "", player: nil, slot_name: nil),
        SaveBuild::Entry.new(skills_code: "OAAAAAAAAAAAAAAA", player: nil, slot_name: nil)
      ]

      result = SaveBuild.call(player: @player, entries: entries)

      refute_predicate result, :ok?
      assert_nil result.teambuild
      assert_equal 0, Teambuild.count
      assert_match(/décodable/, result.errors.first["message"])
    end
  end
end
