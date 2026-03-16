# frozen_string_literal: true

require 'digest'

# Service for deterministic name anonymization by scrambling characters within each name
# Same user always sees the same scrambled name for each character/player
# Scrambling is non-reversible (information is lost in the process)
class AnonymizedNameService
  class << self
    # Scramble characters within a name using Fisher-Yates shuffle with seeded RNG
    # The scrambling is deterministic per user but non-reversible
    # @param name [String] The original name to scramble
    # @param user_seed [String] The seed for deterministic randomization
    # @return [String] The scrambled name
    def scramble_name(name, user_seed)
      return name if name.blank?

      # Create deterministic random generator from user seed + name hash
      # Mixing user seed with name ensures same name scrambles differently per user
      combined_seed = Digest::SHA256.digest("#{user_seed}:#{name}").unpack('Q').first || 0
      rng = Random.new(combined_seed)

      # Convert name to array of characters
      chars = name.chars

      # Fisher-Yates shuffle for deterministic permutation
      (chars.length - 1).downto(1) do |i|
        j = rng.rand(0..i)
        chars[i], chars[j] = chars[j], chars[i]
      end

      chars.join.downcase.split(' ').map(&:capitalize).join(' ')
    end

    # Get the anonymized name for a specific character
    # @param character [Character] The character to anonymize
    # @param user [Player, nil] The user viewing the name
    # @param all_characters [ActiveRecord::Relation] Collection of characters for mapping (unused, kept for API compatibility)
    # @return [String] The anonymized name or original if admin
    def anonymize_character(character, user, all_characters: Character.active)
      return character.igname if character.igname.blank?
      return character.igname if user&.is_admin?

      user_seed = user&.anonymization_seed || 'guest'
      scramble_name(character.igname, user_seed)
    end

    # Get the anonymized name for a player's igname
    # @param igname [String] The original in-game name
    # @param user [Player, nil] The user viewing the name
    # @param all_characters [ActiveRecord::Relation] Collection of characters for mapping (unused, kept for API compatibility)
    # @return [String] The anonymized name or original if admin
    def anonymize_player_name(igname, user, all_characters: Character.active)
      return igname if igname.blank?
      return igname if user&.is_admin?

      user_seed = user&.anonymization_seed || 'guest'
      scramble_name(igname, user_seed)
    end
  end
end
