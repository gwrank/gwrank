module GW
  class SkillStripImage
    SKILLS_DIR = Rails.root.join("app", "assets", "images", "skills")
    PROFESSIONS_DIR = Rails.root.join("app", "assets", "images", "professions")
    ICON_SIZE = 64
    NUMBER_CELL_WIDTH = 16
    PROFESSION_ICON_SIZE = 24

    def self.build(skill_ids)
      images = skill_ids.map do |id|
        path = icon_path(id)
        path ? Vips::Image.new_from_file(path.to_s) : Vips::Image.black(ICON_SIZE, ICON_SIZE, bands: 3)
      end
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
    #
    # Built with #join, not .arrayjoin: arrayjoin pads every cell in the grid
    # to one uniform size (the largest image supplied), which would blow the
    # narrower number/profession cells back up to full skill-icon width.
    # #join concatenates each image at its own native size instead.
    def self.build_grid(rows, numbered: false)
      row_images = rows.each_with_index.map do |row, index|
        cells = [profession_icon(row[:primary]), profession_icon(row[:secondary])] +
          row[:skills].map do |id|
            path = icon_path(id)
            path ? Vips::Image.new_from_file(path.to_s) : Vips::Image.black(ICON_SIZE, ICON_SIZE, bands: 3)
          end
        cells = [number_icon(index + 1)] + cells if numbered
        cells.reduce { |acc, cell| acc.join(cell, :horizontal) }
      end
      grid = row_images.reduce { |acc, row_image| acc.join(row_image, :vertical) }

      file = Tempfile.new(["teambuild", ".png"])
      file.binmode
      grid.write_to_file(file.path)
      file
    end

    def self.icon_path(id)
      return nil if id.zero?

      skill = GW::SkillData.find(id)
      return nil unless skill

      filename = skill.name.gsub(" ", "_").gsub(/['"()!,]/, "") + ".jpg"
      path = SKILLS_DIR.join(filename)
      File.exist?(path) ? path : nil
    end

    # Skill icons are opaque JPGs; profession icons are RGBA PNGs at a
    # different size, so arrayjoin would refuse to mix them (band-count
    # mismatch) without flattening the alpha and resizing to match first.
    # Rendered smaller than the skill icons (PROFESSION_ICON_SIZE < ICON_SIZE)
    # and gravity-centered into an ICON_SIZE-tall cell so the row still lines
    # up with the skill icons beside it.
    def self.profession_icon(profession_id)
      name = GW::TemplateReader::Profession[profession_id.to_i]
      return Vips::Image.black(PROFESSION_ICON_SIZE, ICON_SIZE, bands: 3) if name.nil? || name == "None"

      path = PROFESSIONS_DIR.join("#{name}.png")
      return Vips::Image.black(PROFESSION_ICON_SIZE, ICON_SIZE, bands: 3) unless File.exist?(path)

      icon = Vips::Image.new_from_file(path.to_s).flatten.thumbnail_image(PROFESSION_ICON_SIZE, height: PROFESSION_ICON_SIZE, size: :force)
      icon.gravity("centre", PROFESSION_ICON_SIZE, ICON_SIZE, background: [0, 0, 0])
    end

    NUMBER_COLOR = [255, 255, 255].freeze
    NUMBER_BACKGROUND = [0, 0, 0].freeze

    def self.number_icon(n)
      text = Vips::Image.text(n.to_s, font: "sans 12", dpi: 150)
      colored = text.ifthenelse(NUMBER_COLOR, NUMBER_BACKGROUND, blend: true)
      colored.gravity("centre", NUMBER_CELL_WIDTH, ICON_SIZE, background: NUMBER_BACKGROUND)
    end
  end
end
