require "digest"

module DiscordBot
  # Saves a build posted to Discord as a Teambuild owned by the posting
  # player. Builds a minimal zcx document from raw template codes and
  # delegates validation/upsert/indexing to Teambuilds::Ingest so saved
  # builds behave exactly like API-created ones.
  class SaveBuild
    Entry = Struct.new(:skills_code, :player, :slot_name, keyword_init: true)

    # Fixed project namespace for UUIDv5 derivation (RFC 4122). Changing it
    # would orphan every existing Discord-saved build's identity.
    NAMESPACE_UUID = "2f0626d0-3b13-4490-9322-2147478e1e00"

    def self.call(player:, entries:, name: nil, visibility: "private")
      new(player: player, entries: entries, name: name, visibility: visibility).call
    end

    def initialize(player:, entries:, name:, visibility:)
      @player = player
      @entries = entries
      @name = name
      @visibility = visibility
    end

    def call
      return undecodable_failure if decoded_characters.empty?

      Teambuilds::Ingest.call(
        player: @player,
        source_uuid: source_uuid,
        document: document,
        visibility: @visibility
      )
    end

    private

    def undecodable_failure
      Teambuilds::Ingest::Result.new(false, nil, [undecodable_error], false, false)
    end

    def undecodable_error
      { "path" => "$", "code" => "no_decodable_characters",
        "message" => "Aucun code de template décodable dans ce contenu" }
    end

    def source_uuid
      uuid_v5(NAMESPACE_UUID, entries_with_code.map(&:skills_code).join("\n"))
    end

    # version mirrors data/teambuild_example.zcx so downloaded .zcx files
    # import cleanly back into paw.ned.
    def document
      {
        "version" => 18,
        "name" => @name.to_s,
        "characters" => decoded_characters
      }
    end

    def entries_with_code
      @entries.select { |entry| entry.skills_code.present? }
    end

    def decoded_characters
      @decoded_characters ||= entries_with_code.filter_map { |entry| character_document(entry) }
    end

    def character_document(entry)
      reader = GW::TemplateReader.decode!(entry.skills_code)
      {
        "name" => entry.player.to_s,
        "assignment" => entry.slot_name.to_s,
        "primaryProfession" => reader.primary,
        "secondaryProfession" => reader.secondary,
        "skillIds" => reader.skills,
        "attributes" => reader.attributes.map { |(id, points)| { "id" => id, "points" => points } }
      }
    rescue GW::TemplateReader::InvalidCode
      nil
    end

    # Digest::UUID ships behind a require that fails on this Ruby build, so
    # implement RFC 4122 §4.3 directly: SHA-1 over namespace+name, version
    # nibble forced to 5, variant bits forced to 10xx. `.b` coerces pasted
    # text to binary so high-bit UTF-8 cannot break the digest concat.
    def uuid_v5(namespace, name)
      ns_bytes = [namespace.delete("-")].pack("H*")
      bytes = Digest::SHA1.digest(ns_bytes + name.to_s.b)[0, 16].unpack("C*")
      bytes[6] = (bytes[6] & 0x0F) | 0x50
      bytes[8] = (bytes[8] & 0x3F) | 0x80
      hex = bytes.pack("C*").unpack1("H*")
      [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join("-")
    end
  end
end
