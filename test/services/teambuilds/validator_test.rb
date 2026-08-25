require "test_helper"

module Teambuilds
  class ValidatorTest < ActiveSupport::TestCase
    setup do
      @doc = load_zcx
    end

    def errors_for(mutated)
      Validator.validate(mutated)
    end

    test "accepts the reference document" do
      assert_empty errors_for(@doc)
    end

    test "rejects a non-object root" do
      assert_equal ["not_an_object"], errors_for([]).map { |e| e["code"] }
    end

    test "rejects known keys in wrong case" do
      @doc["Name"] = "x"
      assert_equal ["wrong_case"], errors_for(@doc).map { |e| e["code"] }
    end

    test "rejects character keys in wrong case recursively in variants" do
      variant = JSON.parse(@doc["characters"][0].to_json)
      variant["SkillIds"] = [0, 0, 0, 0, 0, 0, 0, 0]
      variant["variants"] = []
      @doc["characters"][0]["variants"] << variant
      assert_equal ["wrong_case"], errors_for(@doc).map { |e| e["code"] }
    end

    test "rejects null arrays anywhere" do
      @doc["characters"] = nil
      assert_includes errors_for(@doc).map { |e| e["code"] }, "null_array"
      @doc = load_zcx
      @doc["tags"] = nil
      assert_includes errors_for(@doc).map { |e| e["code"] }, "null_array"
    end

    test "rejects duplicated attribute ids including variants" do
      @doc["characters"][0]["attributes"] << { "id" => 11, "points" => 5 }
      assert_equal ["duplicate_attribute_id"], errors_for(@doc).map { |e| e["code"] }
    end

    test "rejects more than 12 root characters" do
      extra = JSON.parse(@doc["characters"][0].to_json)
      12.times { @doc["characters"] << extra }
      assert_equal ["too_many_characters"], errors_for(@doc).map { |e| e["code"] }
    end

    test "rejects flattened trees over 512 characters including variants" do
      variant = JSON.parse(@doc["characters"][0].to_json)
      variant["variants"] = []
      @doc["characters"] = Array.new(12) { JSON.parse(variant.to_json) }
      @doc["characters"].each do |character|
        43.times { character["variants"] << JSON.parse(variant.to_json) }
      end
      errors = errors_for(@doc)
      code_errors = errors.select { |e| e["code"] == "too_many_characters" }
      assert_equal 1, code_errors.size
      assert_equal "$.characters", code_errors.first["path"]
    end

    test "accepts exactly 512 characters including variants" do
      leaf = JSON.parse(@doc["characters"][0].to_json)
      leaf["variants"] = []
      @doc["characters"] = Array.new(8) { JSON.parse(leaf.to_json) }
      @doc["characters"].each { |c| 63.times { c["variants"] << JSON.parse(leaf.to_json) } }
      assert_empty errors_for(@doc)
    end

    test "rejects skillIds without exactly 8 integers" do
      @doc["characters"][0]["skillIds"].pop
      assert_equal ["invalid_skill_ids"], errors_for(@doc).map { |e| e["code"] }
    end

    test "tolerates unknown fields and unknown closed-list values" do
      @doc["futureField"] = { "whatever" => 1 }
      @doc["natureRituals"] = [1156, 999_999]
      assert_empty errors_for(@doc)
    end

    test "reports equipment wrong case inside weapon sets" do
      @doc["characters"][0]["equipment"]["WeaponSets"] = []
      codes = errors_for(@doc).map { |e| e["code"] }
      assert_includes codes, "wrong_case"
    end

    test "tolerates an absent characters key while rejecting explicit null" do
      assert_empty errors_for({ "version" => 18 })
      @doc["characters"] = nil
      assert_includes errors_for(@doc).map { |e| e["code"] }, "null_array"
    end

    test "accepts free-form tags" do
      @doc["tags"] = ["GvG", "meta", "à tester", "Ramstram"]
      assert_empty errors_for(@doc)
    end

    test "accepts canonical tags case-insensitively" do
      @doc["tags"] = ["gvg", "PvE"]
      assert_empty errors_for(@doc)
    end

    test "rejects non-string tags" do
      @doc["tags"] = ["GvG", 42]
      assert_includes errors_for(@doc).map { |e| e["code"] }, "invalid_tag"
    end

    test "rejects empty or whitespace-only tags" do
      @doc["tags"] = [""]
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
      @doc["tags"] = ["   "]
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
    end

    test "rejects tags over 64 characters" do
      @doc["tags"] = ["x" * 65]
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
      @doc["tags"] = ["x" * 64]
      assert_empty errors_for(@doc)
    end

    test "rejects more than 24 tags" do
      @doc["tags"] = Array.new(25) { |i| "tag#{i}" }
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
      @doc["tags"] = Array.new(24) { |i| "tag#{i}" }
      assert_empty errors_for(@doc)
    end

    test "rejects the reserved author root key" do
      @doc["author"] = "someone"
      errors = errors_for(@doc)

      assert_includes errors.map { |e| e["code"] }, "reserved_key"
      assert errors.any? { |e| e["path"] == "$.author" }
    end
  end
end
