# frozen_string_literal: true

namespace :professions do
  task setup: :environment do
    Rake::Task["professions:import"].invoke
  end

  task import: :environment do
    professions = File.read(Rails.root.join('data', 'code_professions.txt')).split("\n")
    professions.each do |profession|
      split = profession.split(' ')
      profession_id = split[0]
      profession_name = split[1]
      profession_short_name = split[2]
      profession = Profession.where(profession_id: profession_id).first_or_create!
      profession.update!(
        name: profession_name,
        short_name: profession_short_name
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
