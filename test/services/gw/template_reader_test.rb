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

    # type: 2 (not 14), same primary/secondary/skills shape as VALID_CODE's header otherwise
    WRONG_TYPE_CODE = "CQAAQAAAAAAAAAAAAAAAAAAAAAAAAA".freeze
    # decodes to primary: 0 (None)
    NONE_PRIMARY_CODE = "OAAAAAAAAAAAAAAA".freeze
    # decodes to a valid type/version/primary, but skill id 4090 (doesn't exist)
    UNKNOWN_SKILL_CODE = "OQAAQ6/AAAAAAAAAAAAAAAAAAAAAAA".freeze

    test "decode! returns a reader for a valid skill template code" do
      reader = TemplateReader.decode!(VALID_CODE)

      assert_equal 1, reader.primary
      assert_equal 6, reader.secondary
    end

    test "decode! raises InvalidCode for characters outside the base64 alphabet" do
      assert_raises(TemplateReader::InvalidCode) { TemplateReader.decode!("not a valid code!!") }
    end

    test "decode! raises InvalidCode for a non-skill-template type" do
      assert_raises(TemplateReader::InvalidCode) { TemplateReader.decode!(WRONG_TYPE_CODE) }
    end

    test "decode! raises InvalidCode when the primary profession is None" do
      assert_raises(TemplateReader::InvalidCode) { TemplateReader.decode!(NONE_PRIMARY_CODE) }
    end

    test "decode! raises InvalidCode when a skill id doesn't resolve" do
      assert_raises(TemplateReader::InvalidCode) { TemplateReader.decode!(UNKNOWN_SKILL_CODE) }
    end
  end
end
