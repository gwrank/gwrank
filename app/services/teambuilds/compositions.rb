# frozen_string_literal: true

module Teambuilds
  # Résout les compositions pilotées par les locks d'un document zcx.
  # Chaque composition sélectionne un nœud par ligne racine : le membre du
  # lock le plus profond dans le sous-arbre de la racine (l'ordre DFS départage
  # les égalités de profondeur), ou la racine elle-même si elle n'est pas
  # référencée. Sans locks, une seule composition contenant les racines.
  class Compositions
    Entry = Data.define(:uuid, :node, :depth)
    Lock = Data.define(:node, :index)

    def self.of(document)
      new(document).call
    end

    def initialize(document)
      @document = document.is_a?(Hash) ? document : {}
    end

    def call
      return [] if buckets.empty?

      compositions = valid_locks.map { |lock| locked_composition(lock) }.compact
      compositions.empty? ? [base_composition] : compositions
    end

    private

    def buckets
      @buckets ||= Array(@document["characters"]).select { |node| node.is_a?(Hash) }.map do |root|
        [].tap do |bucket|
          walker = lambda do |node, depth|
            bucket << Entry.new(uuid(node), node, depth)
            Array(node["variants"]).each { |variant| walker.call(variant, depth + 1) if variant.is_a?(Hash) }
          end
          walker.call(root, 0)
        end
      end
    end

    def uuid(node)
      id = node["id"]
      id.is_a?(String) && id.present? ? id : nil
    end

    def registry
      @registry ||= buckets.flatten(1).each_with_object({}) do |entry, map|
        map[entry.uuid] ||= entry.node if entry.uuid
      end
    end

    def valid_locks
      @valid_locks ||= Array(@document["locks"])
                       .select { |lock| lock.is_a?(Hash) && lock["memberIds"].is_a?(Array) }
                       .each_with_object({}) do |lock, seen|
                         seen[lock["index"].to_i] ||= Lock.new(lock, lock["index"].to_i)
                       end.values
                       .sort_by(&:index)
    end

    def base_composition
      { id: nil, index: nil, color: nil,
        characters: buckets.map { |bucket| bucket.first.node } }
    end

    def locked_composition(lock)
      members = lock.node["memberIds"].filter_map { |id| registry[id] if id.is_a?(String) && id.present? }
      return nil if members.empty?

      { id: "composition-#{lock.index}",
        index: lock.index,
        color: lock.node["color"],
        characters: buckets.map { |bucket| resolve_node(bucket, members) } }
    end

    def resolve_node(bucket, members)
      candidates = bucket.select { |entry| members.any? { |node| node.equal?(entry.node) } }
      return bucket.first.node if candidates.empty?

      candidates.max_by(&:depth).node
    end
  end
end
