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
end
