require "test_helper"

class Gw1::TemplateCodeTest < ActiveSupport::TestCase
  def encode(primary:, secondary:, skills:, attributes: [])
    Gw1::TemplateCode.new(
      primary_profession_id: primary,
      secondary_profession_id: secondary,
      skill_ids: skills,
      attributes: attributes
    ).call
  end

  test "reproduces a known Paragon build code exactly" do
    code = encode(
      primary: 9, secondary: 0,
      skills: [1600, 1546, 1553, 1557, 1584, 0, 0, 2],
      attributes: [[37, 12], [40, 12]]
    )
    assert_equal "OQCiUyo8AkVwR4KMMGAAAEAA", code
  end

  test "encodes three attributes with variable-width ids" do
    code = encode(
      primary: 3, secondary: 4,
      skills: [123, 456, 789, 101, 202, 303, 404, 505],
      attributes: [[13, 12], [16, 3], [15, 10]]
    )
    assert_equal "OwQT0Y48UZPQuKuMUmXiyyP", code
  end

  test "encodes minimal build without secondary or attributes" do
    code = encode(primary: 1, secondary: nil, skills: [354])
    assert_equal "OQAAEiFAAAAAAAAAAA", code
  end

  test "pads missing skills as empty slots and takes at most eight" do
    code = encode(primary: 6, secondary: 5, skills: [1010])
    assert_equal 19, code.length # 111 payload bits => 114 => 19 base64 chars
  end

  test "clamps attribute points into four bits instead of raising" do
    code = encode(primary: 3, secondary: nil, skills: [], attributes: [[13, 99]])
    assert_not_empty code
  end

  test "round-trips through the documented decoder layout" do
    code = encode(
      primary: 2, secondary: 3,
      skills: [1, 2, 3, 4, 5, 6, 7, 8],
      attributes: [[44, 10], [0, 2]]
    )
    bits = code.chars.flat_map do |char|
      ("%06b" % Gw1::TemplateCode::BASE64MAP.index(char)).reverse.chars.map(&:to_i)
    end
    read = lambda do |pos, width|
      value = 0
      width.times { |i| value |= bits[pos + i] << i }
      [value, pos + width]
    end
    pos = 0
    type, pos = read.call(pos, 4)
    version, pos = read.call(pos, 4)
    prof_code, pos = read.call(pos, 2)
    primary, pos = read.call(pos, prof_code * 2 + 4)
    secondary, pos = read.call(pos, prof_code * 2 + 4)
    attr_count, pos = read.call(pos, 4)
    attr_code, pos = read.call(pos, 4)
    attrs = []
    attr_count.times do
      id, pos = read.call(pos, attr_code + 4)
      points, pos = read.call(pos, 4)
      attrs << [id, points]
    end
    skill_code, pos = read.call(pos, 4)
    skills = []
    8.times do
      sid, pos = read.call(pos, skill_code + 8)
      skills << sid
    end
    tail, _pos = read.call(pos, 1)

    assert_equal 14, type
    assert_equal 0, version
    assert_equal 2, primary
    assert_equal 3, secondary
    assert_equal [[44, 10], [0, 2]], attrs
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8], skills
    assert_equal 0, tail
  end
end
