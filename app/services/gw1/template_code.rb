module Gw1
  class TemplateCode
    BASE64MAP = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    def initialize(primary_profession_id:, secondary_profession_id:, skill_ids:, attributes: [])
      @primary = primary_profession_id.to_i
      @secondary = secondary_profession_id.to_i
      @skills = Array(skill_ids).first(8).map(&:to_i)
      @skills << 0 while @skills.size < 8
      @attributes = Array(attributes)
      raise ArgumentError, "too many attributes (max 15)" if @attributes.size > 15
      @attributes.map! { |(id, points)| [id.to_i, points.to_i.clamp(0, 15)] }
    end

    def call
      bits = []
      writer = lambda do |value, width|
        raise ArgumentError, "#{value} exceeds #{width} bits" if value.negative? || value >= (1 << width)
        width.times { |i| bits << ((value >> i) & 1) }
      end

      writer.(TEMPLATE_TYPE, 4)
      writer.(VERSION, 4)
      writer.(PROFESSION_WIDTH_CODE, 2)
      writer.(@primary, 4)
      writer.(@secondary, 4)

      writer.(@attributes.size, 4)
      attr_bits = attribute_width
      writer.(attr_bits - POINTS_WIDTH, 4)
      @attributes.each do |(id, points)|
        writer.(id, attr_bits)
        writer.(points, POINTS_WIDTH)
      end

      skill_bits = needed_width(@skills.max, minimum: 8)
      writer.(skill_bits - 8, 4)
      @skills.each { |sid| writer.(sid, skill_bits) }

      writer.(0, 1)

      pad_to = (bits.length / 6.0).ceil * 6
      (pad_to - bits.length).times { bits << 0 }
      bits.each_slice(6).map { |chunk| BASE64MAP[chunk.reverse.join.to_i(2)] }.join
    end

    private

    TEMPLATE_TYPE = 14
    VERSION = 0
    PROFESSION_WIDTH_CODE = 0
    POINTS_WIDTH = 4
    private_constant :TEMPLATE_TYPE, :VERSION, :PROFESSION_WIDTH_CODE, :POINTS_WIDTH

    def attribute_width
      max_id = @attributes.map(&:first).max || 0
      return 4 if max_id.zero?
      needed_width(max_id, minimum: 4)
    end

    def needed_width(value, minimum:)
      width = minimum
      width += 1 while value >= (1 << width)
      width
    end
  end
end
