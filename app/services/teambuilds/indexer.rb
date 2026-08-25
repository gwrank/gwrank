module Teambuilds
  class Indexer
    def self.call(teambuild)
      new(teambuild).call
    end

    def initialize(teambuild)
      @teambuild = teambuild
      @document = teambuild.document || {}
    end

    def call
      assign_scalars
      rebuild_characters
      @teambuild
    end

    private

    def assign_scalars
      @teambuild.name = @document["name"].to_s
      @teambuild.tags = canonical_tags
      @teambuild.game_mode = @document["gameMode"].to_s
      @teambuild.player_count = root_characters.size
      @teambuild.document_hash = DocumentHash.of(@document)
    end

    def canonical_tags
      Array(@document["tags"]).filter_map do |tag|
        next unless tag.is_a?(String)
        Teambuilds::Validator::ALLOWED_TAGS.find { |allowed| allowed.casecmp(tag).zero? } || tag
      end.uniq
    end

    def root_characters
      characters = @document["characters"]
      return [] unless characters.is_a?(Array)
      characters.select { |character| character.is_a?(Hash) }
    end

    def rebuild_characters
      @teambuild.teambuild_characters.destroy_all
      indexed_characters.each_with_index { |character, position| build_row(character, position) }
    end

    def indexed_characters
      [].tap do |flat|
        walk = lambda do |character|
          flat << character
          Array(character["variants"]).each { |variant| walk.call(variant) if variant.is_a?(Hash) }
        end
        root_characters.each { |character| walk.call(character) }
      end
    end

    def build_row(character, position)
      @teambuild.teambuild_characters.build(
        position: position,
        name: character["name"].to_s,
        assignment: character["assignment"].to_s,
        primary_profession_id: profession_for(character["primaryProfession"]),
        secondary_profession_id: profession_for(character["secondaryProfession"]),
        elite_skill_id: elite_skill_id(character),
        dominant_attribute: DominantAttribute.of(character)
      )
    end

    def profession_for(code)
      code.to_i.zero? ? nil : Profession.find_by(profession_id: code)&.id
    end

    def elite_skill_id(character)
      ids = Array(character["skillIds"]).map(&:to_i).reject(&:zero?)
      elites = Skill.where(is_elite: true, skill_id: ids).index_by(&:skill_id)
      ids.lazy.filter_map { |skill_id| elites[skill_id]&.id }.first
    end
  end
end
