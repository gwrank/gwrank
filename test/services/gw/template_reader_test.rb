require "test_helper"

module GW
  class TemplateReaderTest < ActiveSupport::TestCase
    VALID_CODE = "OQYTgmILZipQA4cQr4nQqoScvCA".freeze

    test "new decodes a valid skill template code" do
      reader = TemplateReader.new(VALID_CODE)

      assert_equal 14, reader.template
      assert_equal 0, reader.version
      assert_equal 1, reader.primary
      assert_equal 6, reader.secondary
      assert_equal [[8, 3], [17, 12], [18, 12]], reader.attributes
      assert_equal [332, 2, 231, 346, 319, 338, 2197, 1403], reader.skills
    end

    test "new falls back to a dummy all-zero code for invalid characters, without raising" do
      reader = TemplateReader.new("not a valid code!!")

      assert_equal "OAAAAAAAAAAAAAAA", reader.code
      assert_equal 0, reader.primary
    end
  end
end
