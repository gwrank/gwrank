namespace :skills do
  task import: :environment do
    skills = File.read(Rails.root.join('data', 'code_skills.txt')).split("\n")
    skills.each do |skill|
      skill_id = skill.split(' ').first
      skill_name = skill.split(' ')[1..-1].join(' ')
      Skill.where(skill_id: skill_id).first_or_create(
        name: skill_name
      )
    end
  end
end
