class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :title
      t.string :canonical_title
      t.string :source_url
      t.jsonb :image, default: {}
      t.string :type
      t.string :subtype
      t.string :rarity
      t.integer :value
      t.string :campaign
      t.jsonb :notes, default: {}
      t.string :categories, array: true, default: []
      t.jsonb :raw_infobox, default: {}
      t.jsonb :stats, default: {}
      t.string :common_salvage
      t.string :rare_salvage
      t.jsonb :rolls, default: {}
      t.string :weapon_type
      t.string :weapon_range
      t.string :parts, array: true, default: []

      t.timestamps
    end
  end
end
