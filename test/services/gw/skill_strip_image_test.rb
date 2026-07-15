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

    test "build_grid stacks each row's profession icons and 8 skill icons into one grid image" do
      row = { primary: 1, secondary: 6, skills: [332, 2, 231, 346, 319, 338, 2197, 1403] }
      rows = [row, row, row]

      file = SkillStripImage.build_grid(rows)
      image = Vips::Image.new_from_file(file.path)

      assert_equal 64 * 10, image.width
      assert_equal 64 * 3, image.height
    ensure
      file&.close!
    end

    test "build_grid renders a blank icon for a secondary profession of None" do
      row = { primary: 1, secondary: 0, skills: Array.new(8, 0) }

      file = SkillStripImage.build_grid([row])
      image = Vips::Image.new_from_file(file.path)

      assert_equal 64 * 10, image.width
      assert_equal 64, image.height
    ensure
      file&.close!
    end

    test "profession_icon returns a same-sized, 3-band image for a known profession" do
      image = SkillStripImage.profession_icon(1) # Warrior

      assert_equal 64, image.width
      assert_equal 64, image.height
      assert_equal 3, image.bands
    end

    test "profession_icon returns a blank placeholder for None" do
      image = SkillStripImage.profession_icon(0)

      assert_equal 64, image.width
      assert_equal 64, image.height
      assert_equal 3, image.bands
    end

    test "build_grid with numbered: true adds a leading row-number column" do
      row = { primary: 1, secondary: 6, skills: [332, 2, 231, 346, 319, 338, 2197, 1403] }
      rows = [row, row, row]

      file = SkillStripImage.build_grid(rows, numbered: true)
      image = Vips::Image.new_from_file(file.path)

      assert_equal 64 * 11, image.width
      assert_equal 64 * 3, image.height
    ensure
      file&.close!
    end

    test "number_icon returns a same-sized, 3-band image" do
      image = SkillStripImage.number_icon(8)

      assert_equal 64, image.width
      assert_equal 64, image.height
      assert_equal 3, image.bands
    end
  end
end
