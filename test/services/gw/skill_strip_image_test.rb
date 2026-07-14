require "test_helper"

module GW
  class SkillStripImageTest < ActiveSupport::TestCase
    test "build joins all 8 skill icons into one strip, left to right" do
      skill_ids = [332, 2, 231, 346, 319, 338, 2197, 1403]

      file = SkillStripImage.build(skill_ids)
      image = Vips::Image.new_from_file(file.path)

      assert_equal 64 * 8, image.width
      assert_equal 64, image.height
    ensure
      file&.close!
    end

    test "build renders empty (id 0) slots using the placeholder icon" do
      skill_ids = [332, 0, 0, 0, 0, 0, 0, 0]

      file = SkillStripImage.build(skill_ids)
      image = Vips::Image.new_from_file(file.path)

      assert_equal 64 * 8, image.width
    ensure
      file&.close!
    end

    test "icon_path falls back to the placeholder for an unknown skill id" do
      assert_equal SkillStripImage::PLACEHOLDER_PATH, SkillStripImage.icon_path(999_999_999)
    end

    test "icon_path falls back to the placeholder when the icon file is missing on disk" do
      # "Signet of Capture" (id 3) resolves in SkillData but has no matching jpg on disk.
      skill = GW::SkillData.find(3)
      assert_equal "Signet of Capture", skill.name
      assert_equal SkillStripImage::PLACEHOLDER_PATH, SkillStripImage.icon_path(3)
    end
  end
end
