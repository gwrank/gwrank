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
