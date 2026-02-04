# frozen_string_literal: true

namespace :items do
  task import: :environment do
    campaigns = Dir.children(Rails.root.join('data', 'items'))
    campaigns.each do |campaign|
      subtypes = Dir.children(Rails.root.join('data', 'items', campaign))
      subtypes.each do |subtype|
        files = Dir.glob("#{Rails.root.join('data', 'items', campaign, subtype)}/**/*.json")
        files.each do |file|
          content = File.read(Rails.root.join('data', 'items', campaign, subtype, file))
          json = JSON.parse(content)

          item = Item.where(source_url: json.dig("source_url")).first_or_initialize
          item.assign_attributes(json.except("extraction_method", "_parser_meta", "_phase2_classification"))
          item.save
        end
      end
    end
  end
end
