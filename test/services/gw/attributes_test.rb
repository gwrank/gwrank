require "test_helper"

module GW
  class AttributesTest < ActiveSupport::TestCase
    test "name_for returns the attribute name for a known id" do
      assert_equal "Strength", Attributes.name_for(17)
      assert_equal "Axe Mastery", Attributes.name_for(18)
      assert_equal "Air Magic", Attributes.name_for(8)
    end

    test "name_for returns nil for an unknown id" do
      assert_nil Attributes.name_for(999)
    end
  end
end
