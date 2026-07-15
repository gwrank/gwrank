module GW
  class SkillStripImage
    SKILLS_DIR = Rails.root.join("app", "assets", "images", "skills")
    PROFESSIONS_DIR = Rails.root.join("app", "assets", "images", "professions")
    PLACEHOLDER_PATH = SKILLS_DIR.join("Unknown_Junundu_Ability.jpg")
    ICON_SIZE = 64

    def self.build(skill_ids)
      images = skill_ids.map { |id| Vips::Image.new_from_file(icon_path(id).to_s) }
      strip = Vips::Image.arrayjoin(images, across: images.size)

      file = Tempfile.new(["build", ".png"])
      file.binmode
      strip.write_to_file(file.path)
      file
    end

    # Same skill-icon strips as .build, but stacked into a single grid image
    # (one row of primary + secondary profession icons, then 8 skill icons,
    # per row) instead of one attachment per row - keeps a whole team build
    # to one embed/one attachment. With numbered: true, each row also gets a
    # leading cell with its 1-based row number, to match it up with the
    # numbered template-code list rendered as text underneath.
    def self.build_grid(rows, numbered: false)
      columns = rows.first[:skills].size + 2 + (numbered ? 1 : 0)
      images = rows.each_with_index.flat_map do |row, index|
        row_images = [profession_icon(row[:primary]), profession_icon(row[:secondary])] +
          row[:skills].map { |id| Vips::Image.new_from_file(icon_path(id).to_s) }
        numbered ? [number_icon(index + 1)] + row_images : row_images
      end
      grid = Vips::Image.arrayjoin(images, across: columns)

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

    # Skill icons are opaque JPGs; profession icons are RGBA PNGs at a
    # different size, so arrayjoin would refuse to mix them (band-count
    # mismatch) without flattening the alpha and resizing to match first.
    def self.profession_icon(profession_id)
      name = GW::TemplateReader::Profession[profession_id.to_i]
      return Vips::Image.black(ICON_SIZE, ICON_SIZE, bands: 3) if name.nil? || name == "None"

      path = PROFESSIONS_DIR.join("#{name}.png")
      return Vips::Image.black(ICON_SIZE, ICON_SIZE, bands: 3) unless File.exist?(path)

      Vips::Image.new_from_file(path.to_s).flatten.thumbnail_image(ICON_SIZE, height: ICON_SIZE, size: :force)
    end

    NUMBER_COLOR = [255, 215, 0].freeze
    NUMBER_BACKGROUND = [20, 20, 20].freeze

    def self.number_icon(n)
      text = Vips::Image.text(n.to_s, font: "sans bold 32", dpi: 150)
      colored = text.ifthenelse(NUMBER_COLOR, NUMBER_BACKGROUND, blend: true)
      colored.gravity("centre", ICON_SIZE, ICON_SIZE, background: NUMBER_BACKGROUND)
    end
  end
end
