module GW
  class TemplateReader
    Template = {14 => 'Skills'}
    Profession = %w[None Warrior Ranger Monk Necromancer Mesmer Elementalist Assassin Ritualist Paragon Dervish]
    ProfessionAbbr = %w[None W R Mo N Me E A Rt P D]
    # Attributes = File.read(File.join(File.dirname(__FILE__), 'code_attributes.txt')).split("\n")
    # Skills     = File.read(File.join(File.dirname(__FILE__), 'code_skills.txt'    )).split("\n")
    Base64Map  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    attr_reader(:code, :template, :version, :primary, :secondary, :attributes, :skills)

    class InvalidCode < StandardError; end

    def self.decode!(code)
      reader = new(code)
      raise InvalidCode, "not a valid base64 template string" unless reader.code == code
      raise InvalidCode, "not a skill template" unless reader.template == 14 && reader.version.zero?
      raise InvalidCode, "unknown primary profession" unless (1..10).cover?(reader.primary)
      raise InvalidCode, "unknown skill id" unless reader.skills.all? { |id| id.zero? || GW::SkillData.find(id) }

      reader
    end

    def initialize(code)
      if template_valid?(code)
        @code = code.dup.freeze
      else
        @code = 'OAAAAAAAAAAAAAAA'.freeze
      end
      @data = decode64(@code)

      @template  = extract!(4)
      @version   = extract!(4)
      bits_pro   = extract!(2) * 2 + 4
      @primary   = extract!(bits_pro)
      @secondary = extract!(bits_pro)

      attrs      = extract!(4)
      bits_att   = extract!(4) + 4
      @attributes = []
      attrs.times {
        @attributes << [extract!(bits_att), extract!(4)]
      }

      bits_ski = extract!(4) + 8
      @skills = []
      8.times {
        @skills << extract!(bits_ski)
      }
    end

    def display o = $stdout
      o.puts("*   Template: #{Template[template]}")
      o.puts("*    Version: #{version}")
      o.puts("*       Code: #{code}")
      o.puts("* Profession: #{Profession[primary]} /" \
        " #{Profession[secondary]}")
      o.puts
      o.puts("* Attributes:")
      o.puts
      @attributes.each{ |attribute|
        o.puts("  - %20s %2d" % [attribute.first, attribute.last])
      }
      o.puts
      o.puts("* Skills:")
      o.puts
      8.times{ |i|
        o.puts("  - %23s" % @skills[i])
      }
    end


    private

    def template_valid?(code)
      code.chars.all? { |c| Base64Map.include? c }
    end

    def decode64(code)
      code.chars.map{ |char| ('%06d' % Base64Map.index(char).to_s(2)).reverse }.join
    end

    def extract!(n)
      @data.slice!(0, n).reverse.to_i(2)
    end
  end
end
