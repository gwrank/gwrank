class PopulateCharacterHashes < ActiveRecord::Migration[8.1]
  def up
    # First, handle any duplicate igname values by archiving duplicates (keep the first)
    # Build a hash of normalized names -> first character id
    # Use Ruby's strip which handles all whitespace (spaces, tabs, newlines)
    name_map = {}
    Character.where.not(igname: nil).order(:id).find_each do |char|
      normalized = char.igname.to_s.strip.downcase
      next if normalized.blank?

      if name_map.key?(normalized)
        # Duplicate found, archive this one
        char.update_columns(is_archived: true)
      else
        # First occurrence, record it
        name_map[normalized] = char.id
      end
    end

    # Handle characters without igname - generate unique hashes
    Character.where(igname: nil).find_each do |c|
      c.update_column(:igname_hash, "empty_#{c.id}")
    end

    # For archived characters with igname, generate unique placeholder hashes first
    Character.where.not(igname: nil).where(is_archived: true).where(igname_hash: nil).find_each do |char|
      hash = "archived_#{char.id}"
      char.update_column(:igname_hash, hash)
    end

    # Hash existing character names (only for non-archived characters)
    Character.where.not(igname: nil).where(igname_hash: nil).where(is_archived: false).find_each do |char|
      hash = Character.hash_name_static(char.igname)
      char.update_column(:igname_hash, hash)
    end

    # Generate anonymization seeds for players
    Player.where(anonymization_seed: nil).find_each do |p|
      p.update(anonymization_seed: SecureRandom.hex(16), slug: nil)
    end
  end

  def down
    # Cannot reverse hashes - this migration is irreversible
    raise ActiveRecord::IrreversibleMigration
  end
end
