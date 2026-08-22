module Teambuilds
  module DominantAttribute
    def self.of(character)
      best = character["attributes"]
             .to_a.select { |entry| entry.is_a?(Hash) }
             .max_by { |entry| entry["points"].to_i }
      return nil unless best
      Gw1::ReferenceTables::ATTRIBUTE_NAMES[best["id"].to_i]
    end
  end
end
