require "test_helper"

module GW
  class PwndTemplateTest < ActiveSupport::TestCase
    VALID_TEAM_CODE = <<~PWND.freeze
      pwnd0001?download pawned2 @ memorial.redeemer.biz | Copyright 2008-2018 Redeemer
      >ZOQWjUyoogOXgiQPYBzgdwubBAAAAAAAACCgbOQSkcMo5ZWyj9WD7hXwPYHs7+TAAAAAAAACCgbOQOk
      UyP1JimDnWD7hXwWYHs7WAAAAAAAAACCgUOAeAMY7LX304uMlmjzJIAAAAAAACCgVOAeAQYbXOUOGXLT
      STciTQAAAAAAACCgUOAeAMBzqJz8s9NLnR7JIAAAAAAACCgUOwoAMW67W9QgcSm+3E1LAAAAAAACCgVO
      wcAQEENgaRCErETfVETQAAAAAAACCg<
    PWND

    test "decode! parses a full pawned2 team export into 8 entries" do
      entries = PwndTemplate.decode!(VALID_TEAM_CODE)

      assert_equal 8, entries.size

      professions = entries.map do |entry|
        reader = GW::TemplateReader.decode!(entry.skills_code)
        GW::TemplateReader::Profession[reader.primary]
      end
      assert_equal %w[Paragon Paragon Paragon Ritualist Ritualist Ritualist Monk Monk], professions
    end

    test "decode! leaves player and slot_name nil when the pawned2 data has neither set" do
      entries = PwndTemplate.decode!(VALID_TEAM_CODE)

      assert_nil entries.first.player
      assert_nil entries.first.slot_name
    end

    test "decode! extracts player name and slot name when present" do
      entry = PwndTemplate.decode!(synthetic_pwnd_text).first

      assert_equal "OQYTgmILZipQA4cQr4nQqoScvCA", entry.skills_code
      assert_equal "Kyra", entry.player
      assert_equal "Spiker", entry.slot_name
    end

    test "decode! raises InvalidCode for text without the pwnd header" do
      assert_raises(PwndTemplate::InvalidCode) { PwndTemplate.decode!("not a pawned2 export") }
    end

    test "decode! raises InvalidCode when the '>' payload marker is missing" do
      assert_raises(PwndTemplate::InvalidCode) { PwndTemplate.decode!("pwnd0001?download no markers here") }
    end

    test "decode! raises InvalidCode for a truncated record" do
      assert_raises(PwndTemplate::InvalidCode) { PwndTemplate.decode!("pwnd0001?download >OQ<") }
    end

    # Discord's slash-command string option is a single-line input: pasting
    # this export's 80-char-wrapped multi-line text into it collapses each
    # embedded newline into a literal space before our code ever sees it.
    # This is the exact text a real user reported failing (with newlines
    # replaced by single spaces, reproducing what Discord actually sends).
    test "decode! parses a team export whose line-wrap newlines arrived as spaces" do
      mangled = <<~PWND.tr("\n", " ").strip.freeze
        pwnd0001?download pawned2 @ memorial.redeemer.biz | Copyright 2008-2018 Redeemer
        >aOQYTEZJjGSqoScvipQr4n4cQAAAAAABSAAQVyBldmkgc2hvY2sKcOQSlcmonpVyHzYvdwBZLsHmD7u
        /EAAAACAJAAWUCBwb3dlciBjcmFja2VkCgaOgQUg17m1TM6WVzjZ2Uc+1+mGBAAAACCJAAOUiBCQSByZ
        W5kCgbOQhkIwhygBszJIGgBuAkuiARI5CAAAACIQAATTWUgc3VyZ2UgcGFjdAobOwok4wQ1TqiTa06XP
        mJ0Xzt3XAAAAAACCJAAQTW8gV29DIHdpbmQKVOwEAQKEbaCErEPgBEaRqMAAAAAAALTW8gcHJvdAoVOw
        cAQaEkE3ETfCENg3NNQAAAAAAALTW8gZnVzZQoVOwcAQaE3ETfCENgaRTQCMAAAAAAAKTW8gc3VwCg<
      PWND

      entries = PwndTemplate.decode!(mangled)

      assert_equal 8, entries.size

      professions = entries.map do |entry|
        reader = GW::TemplateReader.decode!(entry.skills_code)
        primary = GW::TemplateReader::Profession[reader.primary]
        secondary = GW::TemplateReader::Profession[reader.secondary]
        "#{primary}/#{secondary}"
      end
      assert_equal(
        %w[Warrior/Elementalist Paragon/Necromancer Ranger/Necromancer Mesmer/Ritualist
           Monk/Dervish Monk/Warrior Monk/Assassin Monk/Assassin],
        professions
      )
      assert_equal "W evi shock", entries.first.slot_name
    end

    private

    # Builds a minimal synthetic pawned2 export with one build that has a
    # real skills code plus a player name and slot name set — the real
    # example fixture above has neither, so this covers that path.
    def synthetic_pwnd_text
      base64_chr = ->(n) { GW::TemplateReader::Base64Map[n] }
      std_b64    = ->(s) { Base64.strict_encode64(s).delete("=") }

      skills      = "OQYTgmILZipQA4cQr4nQqoScvCA"
      player      = std_b64.call("Kyra")
      description = std_b64.call("Spiker\nAwesome build")

      payload = +""
      payload << base64_chr.call(skills.length) << skills
      payload << base64_chr.call(0) # equipment, 0-length
      3.times { payload << base64_chr.call(0) } # weaponsets, 0-length
      payload << base64_chr.call(0) # flags, 0-length
      payload << base64_chr.call(player.length) << player
      payload << base64_chr.call(description.length / 64) << base64_chr.call(description.length % 64) << description

      "pwnd0001?download pawned2 @ memorial.redeemer.biz\n>#{payload}<"
    end
  end
end
