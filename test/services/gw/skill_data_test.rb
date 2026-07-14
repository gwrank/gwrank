require "test_helper"

module GW
  class SkillDataTest < ActiveSupport::TestCase
    test "find returns name, description, profession, and is_elite for a known skill id" do
      skill = SkillData.find(332)

      assert_equal "Bull's Strike", skill.name
      assert_equal 1, skill.profession
      assert_equal false, skill.is_elite
      assert_match(/knocked down/, skill.description)
    end

    test "find reports an elite skill correctly" do
      skill = SkillData.find(338) # Eviscerate

      assert_equal "Eviscerate", skill.name
      assert skill.is_elite
    end

    test "find accepts a string id" do
      assert_equal SkillData.find(332), SkillData.find("332")
    end

    test "find returns nil for an unknown skill id" do
      assert_nil SkillData.find(999_999)
    end
  end
end
