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
  end
end
