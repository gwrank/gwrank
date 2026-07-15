module GW
  class SkillStripImage
    SKILLS_DIR = Rails.root.join("app", "assets", "images", "skills")
    PLACEHOLDER_PATH = SKILLS_DIR.join("Unknown_Junundu_Ability.jpg")

    def self.build(skill_ids)
      images = skill_ids.map { |id| Vips::Image.new_from_file(icon_path(id).to_s) }
      strip = Vips::Image.arrayjoin(images, across: images.size)

      file = Tempfile.new(["build", ".png"])
      file.binmode
      strip.write_to_file(file.path)
      file
    end

    # Same skill-icon strips as .build, but stacked into a single grid image
    # (one row per skill_ids array) instead of one attachment per row -
    # keeps a whole team build to one embed/one attachment.
    def self.build_grid(rows_of_skill_ids)
      skills_per_row = rows_of_skill_ids.first.size
      images = rows_of_skill_ids.flatten.map { |id| Vips::Image.new_from_file(icon_path(id).to_s) }
      grid = Vips::Image.arrayjoin(images, across: skills_per_row)

      file = Tempfile.new(["teambuild", ".png"])
      file.binmode
      grid.write_to_file(file.path)
      file
    end

    def self.icon_path(id)
      return PLACEHOLDER_PATH if id.zero?

      skill = GW::SkillData.find(id)
      return PLACEHOLDER_PATH unless skill

      filename = skill.name.gsub(" ", "_").gsub(/['"()!,]/, "") + ".jpg"
      path = SKILLS_DIR.join(filename)
      File.exist?(path) ? path : PLACEHOLDER_PATH
    end
  end
end
