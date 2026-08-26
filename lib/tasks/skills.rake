# frozen_string_literal: true

namespace :skills do
  task setup: :environment do
    Rake::Task["skills:import"].invoke
    Rake::Task["skills:import_informations"].invoke
    Rake::Task["skills:update_for_template_codes"].invoke
  end

  task import: :environment do
    unknown_profession = Profession.find_by(profession_id: 0)
    skills = File.read(Rails.root.join('data', 'code_skills.txt')).split("\n")
    skills.each do |skill|
      skill_id = skill.split(' ').first
      skill_name = skill.split(' ')[1..-1].join(' ')
      Skill.where(skill_id: skill_id).first_or_create!(
        name: skill_name,
        profession: unknown_profession
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
      skill.update(template_skill_id: common_skill&.skill_id || skill.skill_id)
    end

    Skill.where.not('name LIKE (?)', '%(PvP)').each do |skill|
      skill.update(template_skill_id: skill.skill_id)
    end
  end

  desc "Backfill Skill#campaign depuis data/campaigns.txt (<skill_id> <campagne>)"
  task update_campaigns: :environment do
    path = ENV.fetch("CAMPAIGNS_FILE") { Rails.root.join("data", "campaigns.txt").to_s }
    abort "Fichier introuvable : #{path}" unless File.exist?(path)
    updated = 0
    File.foreach(path) do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      skill_id, campaign = line.split(/\s+/, 2)
      updated += Skill.where(skill_id: skill_id.to_i).update_all(campaign: campaign)
    end
    puts "#{updated} compétences mises à jour."
  end

  desc "Aligne les noms sur data/skills/desc.json (gw-skilldata) et supprime les skill_id inexistants"
  task repair_from_source: :environment do
    source = JSON.parse(File.read(Rails.root.join('data', 'skills', 'desc.json')))[ 'skilldesc']
    renamed = 0
    deleted = 0

    Skill.find_each do |skill|
      next if skill.skill_id.nil?
      next if source.key?(skill.skill_id.to_s)

      canonical = Skill.where(name: skill.name)
                       .where.not(id: skill.id)
                       .find { |candidate| source.key?(candidate.skill_id.to_s) }
      skill.team_player_skills.update_all(skill_id: canonical.id) if canonical
      Rails.logger.warn "skills:repair_from_source supprime ##{skill.id} (#{skill.name}, id jeu #{skill.skill_id} inexistant)"
      skill.delete
      deleted += 1
    end

    Skill.find_each do |skill|
      next if skill.skill_id.nil?
      authoritative_name = source[skill.skill_id.to_s]&.dig('name')
      next if authoritative_name.nil? || authoritative_name == skill.name

      skill.update!(name: authoritative_name)
      renamed += 1
    end

    puts "#{renamed} compétences renommées, #{deleted} supprimées."
  end

  task clean_unknown_skills: :environment do
    no_skill_id = Skill.find_by(skill_id: 0).id
    Skill.where(name: 'Unknown').each do |skill|
      skill.team_player_skills.update_all(skill_id: no_skill_id)
      skill.delete
    end
  end
end
