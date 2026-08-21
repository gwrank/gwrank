require "test_helper"

module Teambuilds
  class DocumentHashTest < ActiveSupport::TestCase
    test "ignores updatedAt but detects real changes" do
      doc = load_zcx
      touched = JSON.parse(doc.to_json)
      touched["updatedAt"] = "2030-01-01T00:00:00Z"

      assert_equal DocumentHash.of(doc), DocumentHash.of(touched)
      changed = JSON.parse(doc.to_json)
      changed["name"] = "Autre"
      assert_not_equal DocumentHash.of(doc), DocumentHash.of(changed)
    end

    test "is insensitive to key order" do
      doc = load_zcx
      shuffled = JSON.parse(JSON.generate(doc)).to_h { |k, v| [k, v] }.sort.to_h
      assert_equal DocumentHash.of(doc), DocumentHash.of(shuffled)
    end
  end
end
