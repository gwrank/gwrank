require "base64"

module GW
  class PwndTemplate
    class InvalidCode < StandardError; end

    Entry = Struct.new(:skills_code, :player, :slot_name, keyword_init: true)

    BASE64 = GW::TemplateReader::Base64Map

    def self.decode!(text)
      new(text).entries
    end

    def initialize(text)
      @payload = extract_payload(text)
      @offset = 0
    end

    def entries
      result = []
      result << read_entry while @offset < @payload.length
      result
    end

    private

    def extract_payload(text)
      flat = text.to_s.gsub(/[\r\n]/, "")
      raise InvalidCode, "missing pwnd header" unless flat.start_with?("pwnd000")

      start = flat.rindex(">")
      raise InvalidCode, "missing '>' marker" unless start

      finish = flat.index("<", start)
      raise InvalidCode, "missing '<' marker" unless finish && finish > start + 1

      # some clients mangle '+' into a literal space on copy/paste, same
      # normalization the reference pawned2 decoder applies
      flat[(start + 1)...finish].tr(" ", "+")
    end

    def read_entry
      skills_code = read_field
      read_field # equipment, discarded (not rendered by /teambuild)
      3.times { read_field } # weaponsets, discarded
      read_field # flags, undocumented even upstream, discarded
      player = standard_base64_decode(read_field)
      description = standard_base64_decode(read_description_field)
      slot_name, = description.split("\n", 2)

      Entry.new(skills_code: skills_code, player: presence(player), slot_name: presence(slot_name))
    end

    def read_field
      read(base64_ord(read(1)))
    end

    def read_description_field
      length = base64_ord(read(1)) * 64
      length += base64_ord(read(1))
      read(length)
    end

    # Every field read (length-prefix bytes and the fields they describe)
    # routes through this guarded read, so a truncated record raises
    # immediately instead of silently producing a short/garbled field.
    def read(length)
      raise InvalidCode, "truncated record" if @offset + length > @payload.length

      str = @payload[@offset, length]
      @offset += length
      str
    end

    def base64_ord(char)
      index = BASE64.index(char)
      raise InvalidCode, "invalid character: #{char.inspect}" unless index

      index
    end

    # player/description use standard base64 (RFC 3548), unlike the
    # reversed-bit encoding GW::TemplateReader uses for template codes.
    def standard_base64_decode(str)
      return "" if str.empty?

      padded = str + ("=" * ((4 - str.length % 4) % 4))
      Base64.decode64(padded)
    end

    def presence(str)
      str.nil? || str.empty? ? nil : str
    end
  end
end
