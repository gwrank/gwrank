require "test_helper"

module Teambuilds
  class CompositionsTest < ActiveSupport::TestCase
    def character(id, name: "Char #{id[0, 8]}", variants: [])
      { "id" => id, "name" => name, "primaryProfession" => 6,
        "secondaryProfession" => 5, "skillIds" => [1010], "attributes" => [],
        "variants" => variants }
    end

    def document(characters, locks: [])
      { "characters" => characters, "locks" => locks }
    end

    def member_ids(composition)
      composition[:characters].map { |node| node["id"] }
    end

    test "returns empty array when document has no characters" do
      assert_empty Compositions.of(document([]))
    end

    test "returns empty array for a non-hash document" do
      assert_empty Compositions.of(nil)
    end

    test "without locks returns a single base composition with root nodes" do
      root_a = character("aaaaaaaa-0000-0000-0000-000000000001")
      root_b = character("bbbbbbbb-0000-0000-0000-000000000001")

      compositions = Compositions.of(document([root_a, root_b]))

      assert_equal 1, compositions.size
      assert_nil compositions.first[:id]
      assert_nil compositions.first[:index]
      assert_nil compositions.first[:color]
      assert_equal [root_a, root_b], compositions.first[:characters]
    end

    test "creates one composition per lock ordered by index" do
      root = character("aaaaaaaa-0000-0000-0000-000000000001")
      locks = [
        { "index" => 2, "color" => "#1E88E5", "memberIds" => [root["id"]] },
        { "index" => 1, "color" => "#E53935", "memberIds" => [root["id"]] }
      ]

      compositions = Compositions.of(document([root], locks: locks))

      assert_equal [1, 2], compositions.map { |c| c[:index] }
      assert_equal ["composition-1", "composition-2"], compositions.map { |c| c[:id] }
      assert_equal ["#E53935", "#1E88E5"], compositions.map { |c| c[:color] }
    end

    test "resolves the deepest listed node within a root subtree" do
      deep = character("aaaaaaaa-0000-0000-0000-000000000003", name: "Deep")
      mid = character("aaaaaaaa-0000-0000-0000-000000000002", name: "Mid", variants: [deep])
      root = character("aaaaaaaa-0000-0000-0000-000000000001", name: "Root", variants: [mid])
      other = character("bbbbbbbb-0000-0000-0000-000000000001", name: "Other")
      lock = { "index" => 1, "color" => "#E53935",
               "memberIds" => [root["id"], deep["id"], other["id"]] }

      compositions = Compositions.of(document([root, other], locks: [lock]))

      assert_equal 1, compositions.size
      assert_equal [deep, other], compositions.first[:characters]
    end

    test "breaks depth ties with the first node in file order" do
      sibling_a = character("aaaaaaaa-0000-0000-0000-000000000002", name: "Sibling A")
      sibling_b = character("aaaaaaaa-0000-0000-0000-000000000003", name: "Sibling B")
      root = character("aaaaaaaa-0000-0000-0000-000000000001", name: "Root",
                       variants: [sibling_a, sibling_b])
      lock = { "index" => 1, "color" => "#E53935",
               "memberIds" => [sibling_a["id"], sibling_b["id"]] }

      compositions = Compositions.of(document([root], locks: [lock]))

      assert_equal [sibling_a], compositions.first[:characters]
    end

    test "falls back to the root itself when a lock does not reference its subtree" do
      root = character("aaaaaaaa-0000-0000-0000-000000000001", name: "Root")
      other = character("bbbbbbbb-0000-0000-0000-000000000001", name: "Other")
      lock = { "index" => 1, "color" => "#E53935", "memberIds" => [other["id"]] }

      compositions = Compositions.of(document([root, other], locks: [lock]))

      assert_equal [root, other], compositions.first[:characters]
    end

    test "ignores unknown member ids and skips fully unresolvable locks" do
      root = character("aaaaaaaa-0000-0000-0000-000000000001", name: "Root")
      dead_lock = { "index" => 1, "color" => "#43A047",
                    "memberIds" => ["dddddddd-0000-0000-0000-000000000001"] }
      live_lock = { "index" => 2, "color" => "#1E88E5",
                    "memberIds" => ["dddddddd-0000-0000-0000-000000000002", root["id"]] }

      compositions = Compositions.of(document([root], locks: [dead_lock, live_lock]))

      assert_equal 1, compositions.size
      assert_equal "composition-2", compositions.first[:id]
      assert_equal [root], compositions.first[:characters]
    end

    test "filters malformed lock entries" do
      root = character("aaaaaaaa-0000-0000-0000-000000000001", name: "Root")
      locks = [
        "not-a-hash",
        { "index" => 1, "color" => "#E53935" },
        { "index" => 2, "color" => "#1E88E5", "memberIds" => "not-an-array" },
        { "index" => 3, "color" => "#43A047", "memberIds" => [root["id"]] }
      ]

      compositions = Compositions.of(document([root], locks: locks))

      assert_equal 1, compositions.size
      assert_equal "composition-3", compositions.first[:id]
    end

    test "keeps the first occurrence when a uuid appears twice in the tree" do
      twin = character("aaaaaaaa-0000-0000-0000-000000000002", name: "First Twin")
      root_a = character("aaaaaaaa-0000-0000-0000-000000000001", name: "Root A", variants: [twin])
      root_b = character("bbbbbbbb-0000-0000-0000-000000000001", name: "Root B",
                         variants: [character("aaaaaaaa-0000-0000-0000-000000000002", name: "Second Twin")])
      lock = { "index" => 1, "color" => "#E53935", "memberIds" => [twin["id"]] }

      compositions = Compositions.of(document([root_a, root_b], locks: [lock]))

      resolved = compositions.first[:characters]
      assert_equal "First Twin", resolved[0]["name"]
      assert_equal root_b, resolved[1]
    end

    test "treats nodes without usable id as unreferencable roots" do
      anonymous = character(nil, name: "Anonymous")
      referenced = character("bbbbbbbb-0000-0000-0000-000000000001", name: "Referenced")
      lock = { "index" => 1, "color" => "#E53935", "memberIds" => [referenced["id"]] }

      compositions = Compositions.of(document([anonymous, referenced], locks: [lock]))

      assert_equal [anonymous, referenced], compositions.first[:characters]
    end
  end
end
