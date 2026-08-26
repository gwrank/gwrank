class SeedTeambuildTags < ActiveRecord::Migration[8.1]
  TAGS = [%w[GvG gvg], %w[HA ha], %w[RA ra], %w[TA ta], %w[AB ab],
          %w[FA fa], %w[JQ jq], %w[PvP pvp], %w[PvE pve]].freeze

  def up
    TAGS.each_with_index do |(name, slug), index|
      TeambuildTag.find_or_create_by!(slug: slug) do |tag|
        tag.name = name
        tag.position = index + 1
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
