module Teambuilds
  module DocumentHash
    IGNORED_KEYS = %w[updatedAt].freeze

    def self.of(document)
      Digest::SHA256.hexdigest(JSON.generate(canonicalize(document.except(*IGNORED_KEYS))))
    end

    def self.canonicalize(value)
      case value
      when Hash then value.sort.to_h.transform_values { |member| canonicalize(member) }
      when Array then value.map { |member| canonicalize(member) }
      else value
      end
    end
  end
end
