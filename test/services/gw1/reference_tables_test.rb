require "test_helper"

module Gw1
  class ReferenceTablesTest < ActiveSupport::TestCase
    test "ATTRIBUTE_NAMES covers all assigned attribute ids" do
      assert_equal 42, ReferenceTables::ATTRIBUTE_NAMES.size
      assert_equal "Fast Casting", ReferenceTables::ATTRIBUTE_NAMES[0]
      assert_equal "Mysticism", ReferenceTables::ATTRIBUTE_NAMES[44]
      assert_nil ReferenceTables::ATTRIBUTE_NAMES[26]
    end
  end
end
