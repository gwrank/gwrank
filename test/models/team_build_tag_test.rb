require "test_helper"

class TeambuildTagTest < ActiveSupport::TestCase
  test "generates slug from name when absent" do
    TeambuildTag.delete_all
    tag = TeambuildTag.new(name: "GvG")
    assert tag.save
    assert_equal "gvg", tag.slug
  end

  test "strips and downcases a provided slug" do
    TeambuildTag.delete_all
    tag = TeambuildTag.new(name: "Heroes Ascent", slug: "  HA ")
    assert tag.save
    assert_equal "ha", tag.slug
  end

  test "rejects duplicate slug regardless of case" do
    team_build_tags(:gvg)
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
    assert_includes TeambuildTag.ordered.map(&:slug), "legacy"
  end
end
