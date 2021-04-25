# frozen_string_literal: true

namespace :professions do
  task import: :environment do
    professions = File.read(Rails.root.join('data', 'code_professions.txt')).split("\n")
    professions.each do |profession|
      profession_id = profession[0..1]
      profession_name = profession[3..-1]
      Profession.where(profession_id: profession_id).first_or_create(
        name: profession_name
      )
    end
  end

  task clean_unknown_professions: :environment do
    no_profession_id = Profession.find_by(profession_id: 0).id
    Profession.where(name: 'Unknown').each do |profession|
      profession.characters.update_all(profession_id: no_profession_id)
      profession.team_players.update_all(profession_id: no_profession_id)
      profession.delete
    end
  end
end
