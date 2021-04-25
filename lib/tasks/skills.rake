# frozen_string_literal: true

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

  task import_informations: :environment do
    Profession.where.not(name: 'Unknown').each do |profession|
      profession = profession
      filename = "#{profession.name.downcase}.txt"
      skills = File.read(Rails.root.join('data', 'skills', filename)).split("\n")
      skills.each do |skill|
        skill_table = skill.split(' 	')
        name = skill_table[1]
        skill_type = skill_table[2].split('.').first
        is_elite = skill_type.include?('Elite')
        description = skill_table[2].split('.').drop(1).join('.').strip
        Skill.find_by(name: name)&.update(
          skill_type: skill_type,
          is_elite: is_elite,
          description: description,
          profession: profession
        )
      end
    end
  end

  task update_for_template_codes: :environment do
    Skill.where('name LIKE (?)', '%(PvP)').each do |skill|
      skill_common_name = skill.name.gsub(' (PvP)', '')
      common_skill = Skill.find_by(name: skill_common_name)
      skill.update(template_skill_id: common_skill.skill_id)
    end

    Skill.where.not('name LIKE (?)', '%(PvP)').each do |skill|
      skill.update(template_skill_id: skill.skill_id)
    end
  end

  task clean_unknown_skills: :environment do
    no_skill_id = Skill.find_by(skill_id: 0).id
    Skill.where(name: 'Unknown').each do |skill|
      skill.team_player_skills.update_all(skill_id: no_skill_id)
      skill.delete
    end
  end
end
