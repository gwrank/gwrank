require "test_helper"

class TeambuildTagTest < ActiveSupport::TestCase
  test "generates slug from name when absent" do
    tag = TeambuildTag.new(name: "Tombs")
    assert tag.save
    assert_equal "tombs", tag.slug
  end

  test "strips and downcases a provided slug" do
    tag = TeambuildTag.new(name: "Heroes Ascent", slug: "  HeroesAscent ")
    assert tag.save
    assert_equal "heroesascent", tag.slug
  end

  test "rejects duplicate slug regardless of case" do
    teambuild_tags(:gvg)
    dup = TeambuildTag.new(name: "GVG", slug: "GVG")
    refute dup.valid?
    assert dup.errors[:slug].any?
  end

  test "rejects slug with characters outside [a-z0-9]" do
    refute TeambuildTag.new(name: "Bad Tag", slug: "bad tag!").valid?
  end

  test "requires a name" do
    refute TeambuildTag.new(slug: "x").valid?
  end

  test "active_slugs returns active slugs ordered by position" do
    assert_equal %w[gvg ha ra ta ab fa jq pvp pve], TeambuildTag.active_slugs
  end

  test "ordered includes deactivated tags last for admin listing" do
    assert_equal "legacy", TeambuildTag.ordered.last.slug
  end
end
