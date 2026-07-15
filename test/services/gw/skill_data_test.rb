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

    test "find returns the PvP-balanced description for a skill with a PvP split" do
      skill = SkillData.find(17) # Mantra of Resolve

      assert_equal "Mantra of Resolve", skill.name
      assert_match(/5 seconds/, skill.description)
      refute_match(/30\.\.\.90 seconds/, skill.description)
    end

    test "find returns the plain description for a skill with no PvP split" do
      skill = SkillData.find(332) # Bull's Strike, no PvP split

      assert_match(/knocked down/, skill.description)
    end

    test "cost_badge shows energy and recharge for an energy skill" do
      skill = SkillData.find(332) # Bull's Strike: 5 energy, 10 recharge, no cast time

      assert_equal "⚡5 🔄10", skill.cost_badge
    end

    test "cost_badge shows adrenaline for an adrenaline skill" do
      skill = SkillData.find(338) # Eviscerate: 8 adrenaline, no energy/cast/recharge

      assert_equal "🔺8", skill.cost_badge
    end

    test "cost_badge renders a fractional cast time as a unicode fraction" do
      skill = SkillData.find(5) # Power Block: 15 energy, 1/4 cast, 20 recharge

      assert_equal "⚡15 ⏱¼ 🔄20", skill.cost_badge
    end
  end
end
