module Teambuilds
  class Validator
    UUID_RE = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/.freeze

    ROOT_KEYS = %w[
      version id name tags notes createdAt updatedAt characters locks spike flux
      natureRituals roaringWindsRank tranquilityRank gameMode vampiricHits3 vampiricHits5
    ].freeze
    RESERVED_ROOT_KEYS = %w[author].freeze
    CHARACTER_KEYS = %w[
      id name primaryProfession secondaryProfession isFavorite assignment gender skillIds
      attributes titleRanks equipment notes durationBoostersEnabled activeAttributeBoosts variants
    ].freeze
    EQUIPMENT_KEYS = %w[armor weaponSets activeSet items].freeze
    WEAPON_SET_KEYS = %w[items].freeze
    EQUIPMENT_ITEM_KEYS = %w[slot itemId dye modifierIds].freeze
    LOCK_KEYS = %w[index color memberIds].freeze
    SPIKE_MEMBER_KEYS = %w[characterId skills buffs slots weaponDamageType].freeze
    SPIKE_SKILL_KEYS = %w[
      slot weaponDamageType ticks order weaponKind procs conditional threshold
      casterCurrentHp casterMaxHp weaponMod sunderingProc hornbow
    ].freeze

    ARRAY_KEYS = %w[
      tags characters natureRituals locks spike skillIds attributes activeAttributeBoosts
      variants armor weaponSets items modifierIds memberIds buffs slots
    ].freeze

    MAX_ROOT_CHARACTERS = 12
    MAX_TAGS = 24
    TAG_MAX_LENGTH = 64
    SKILL_SLOTS = 8
    MAX_DEPTH = 64
    MAX_TOTAL_CHARACTERS = 512

    def self.validate(document, allowed_tags: nil)
      unless document.is_a?(Hash)
        return [{ "path" => "$", "code" => "not_an_object", "message" => "Le document racine doit être un objet JSON" }]
      end
      new(document, allowed_tags: allowed_tags).call
    end

    attr_reader :errors

    def initialize(document, allowed_tags: nil)
      @document = document
      @allowed_tags = allowed_tags
      @errors = []
      @character_count = 0
    end

    def call
      check_keys("$", @document, ROOT_KEYS)
      reject_reserved_keys("$", @document)
      reject_null_arrays("$", @document, %w[tags natureRituals locks spike])
      validate_tags(@document["tags"])
      validate_characters(@document["characters"]) if @document.key?("characters")
      validate_locks(@document["locks"])
      validate_spike(@document["spike"])
      if @character_count > MAX_TOTAL_CHARACTERS
        add_error("$.characters", "too_many_characters",
                  "L'arbre complet (variants compris) dépasse #{MAX_TOTAL_CHARACTERS} personnages")
      end
      errors
    end

    private

    def add_error(path, code, message)
      errors << { "path" => path, "code" => code, "message" => message }
    end

    def check_keys(path, object, known_keys)
      object.each_key do |key|
        next unless key.is_a?(String)
        match = known_keys.find { |known| known.casecmp(key).zero? }
        next if match.nil? || match == key
        add_error("#{path}.#{key}", "wrong_case", %(La clé "#{key}" doit s'écrire "#{match}" (camelCase strict)))
      end
    end

    def reject_reserved_keys(path, object)
      RESERVED_ROOT_KEYS.each do |key|
        next unless object.key?(key)
        add_error("#{path}.#{key}", "reserved_key",
                  %(La clé "#{key}" est réservée et ne peut pas être stockée))
      end
    end

    def reject_null_arrays(path, object, keys)
      keys.each do |key|
        next unless object.key?(key) && object[key].nil?
        add_error("#{path}.#{key}", "null_array", %(#{key} ne peut pas être null : émettre []))
      end
    end

    def validate_tags(tags)
      return unless tags.is_a?(Array)
      if tags.size > MAX_TAGS
        return add_error("$.tags", "invalid_tag", "Au maximum #{MAX_TAGS} tags sont admis")
      end
      tags.each_with_index do |tag, i|
        next if valid_tag?(tag)
        add_error("$.tags[#{i}]", "invalid_tag",
                  %(Tag invalide : chaîne non vide de #{TAG_MAX_LENGTH} caractères maximum))
      end
      reject_unknown_tags(tags)
    end

    def reject_unknown_tags(tags)
      return unless @allowed_tags
      unknown = tags.select { |tag| valid_tag?(tag) && !@allowed_tags.include?(tag.to_s.downcase) }
      return if unknown.empty?
      add_error("$.tags", "invalid_tag",
                "Liste des tags autorisés disponible sur GET /api/v1/tags. Tags refusés : #{unknown.join(', ')}")
    end

    def valid_tag?(tag)
      tag.is_a?(String) && tag.length <= TAG_MAX_LENGTH && !tag.strip.empty?
    end

    def validate_characters(characters)
      return add_error("$.characters", "null_array", "characters ne peut pas être null : émettre []") if characters.nil?
      unless characters.is_a?(Array)
        return add_error("$.characters", "not_an_array", "characters doit être un tableau")
      end
      if characters.size > MAX_ROOT_CHARACTERS
        add_error("$.characters", "too_many_characters",
                  "Un teambuild contient au maximum #{MAX_ROOT_CHARACTERS} personnages racine")
      end
      characters.each_with_index { |character, i| validate_character(character, "$.characters[#{i}]", 0) }
    end

    def validate_character(character, path, depth)
      return unless character.is_a?(Hash)
      if depth > MAX_DEPTH
        return add_error(path, "max_depth", "Arbre de variantes trop profond")
      end
      @character_count += 1
      check_keys(path, character, CHARACTER_KEYS)
      reject_null_arrays(path, character, %w[skillIds attributes activeAttributeBoosts variants])
      validate_skill_ids(path, character["skillIds"])
      validate_attributes(path, character["attributes"])
      validate_equipment(path, character["equipment"])
      Array(character["variants"]).each_with_index do |variant, i|
        validate_character(variant, "#{path}.variants[#{i}]", depth + 1)
      end
    end

    def validate_skill_ids(path, skill_ids)
      return if skill_ids.nil?
      valid = skill_ids.is_a?(Array) &&
              skill_ids.size == SKILL_SLOTS &&
              skill_ids.all? { |skill_id| skill_id.is_a?(Integer) }
      return if valid
      add_error("#{path}.skillIds", "invalid_skill_ids",
                "skillIds doit contenir exactement #{SKILL_SLOTS} entiers")
    end

    def validate_attributes(path, attributes)
      return unless attributes.is_a?(Array)
      counts = Hash.new(0)
      attributes.each do |attribute|
        counts[attribute["id"]] += 1 if attribute.is_a?(Hash)
      end
      counts.each do |attribute_id, count|
        next unless count > 1
        add_error("#{path}.attributes", "duplicate_attribute_id",
                  %(L'attribut #{attribute_id.inspect} apparaît #{count} fois))
      end
    end

    def validate_equipment(path, equipment)
      return unless equipment.is_a?(Hash)
      equip_path = "#{path}.equipment"
      check_keys(equip_path, equipment, EQUIPMENT_KEYS)
      reject_null_arrays(equip_path, equipment, %w[armor weaponSets items])
      Array(equipment["armor"]).each_with_index { |item, i| validate_item(item, "#{equip_path}.armor[#{i}]") }
      Array(equipment["weaponSets"]).each_with_index do |set, i|
        next unless set.is_a?(Hash)
        set_path = "#{equip_path}.weaponSets[#{i}]"
        check_keys(set_path, set, WEAPON_SET_KEYS)
        reject_null_arrays(set_path, set, %w[items])
        Array(set["items"]).each_with_index { |item, j| validate_item(item, "#{set_path}.items[#{j}]") }
      end
      Array(equipment["items"]).each_with_index { |item, i| validate_item(item, "#{equip_path}.items[#{i}]") }
    end

    def validate_item(item, path)
      return unless item.is_a?(Hash)
      check_keys(path, item, EQUIPMENT_ITEM_KEYS)
      reject_null_arrays(path, item, %w[modifierIds])
    end

    def validate_locks(locks)
      return unless locks.is_a?(Array)
      locks.each_with_index do |lock, i|
        next unless lock.is_a?(Hash)
        path = "$.locks[#{i}]"
        check_keys(path, lock, LOCK_KEYS)
        reject_null_arrays(path, lock, %w[memberIds])
      end
    end

    def validate_spike(members)
      return unless members.is_a?(Array)
      members.each_with_index do |member, i|
        next unless member.is_a?(Hash)
        path = "$.spike[#{i}]"
        check_keys(path, member, SPIKE_MEMBER_KEYS)
        reject_null_arrays(path, member, %w[skills buffs slots])
        Array(member["skills"]).each_with_index do |entry, j|
          next unless entry.is_a?(Hash)
          check_keys("#{path}.skills[#{j}]", entry, SPIKE_SKILL_KEYS)
        end
      end
    end
  end
end
