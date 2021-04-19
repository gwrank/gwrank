# frozen_string_literal: true

namespace :tournaments do
  task add_archives: :environment do
    (2008..2010).each do |year|
      (1..12).each do |month|
        next if year == 2010 && month > 7
        Tournament.create(year: year, month: month)
      end
    end
  end

  task import_from_observer: :environment do
    years = Dir.children(Rails.root.join('data', 'observer'))
    years.each do |year|
      months = Dir.children(Rails.root.join('data', 'observer', year))
      months.each do |month|
        files = Dir.children(Rails.root.join('data', 'observer', year, month))
        tournament = Tournament.find_by(year: year, month: month)
        next if tournament.present?
        tournament = Tournament.create(year: year, month: month)

        files.each do |filename|
          content = File.read(Rails.root.join('data', 'observer', year, month, filename))

          filename_table = filename.split('.')[0].split('-')
          round = filename_table[0]
          number_on_round = filename_table[1]
          first_team_tag = filename_table[2]
          second_team_tag = filename_table[4]

          match = Match.create(
            tournament: tournament,
            round: round,
            number_on_round: number_on_round
          )

          guilds = []
          guilds << Guild.where(tag: first_team_tag).first_or_create(name: first_team_tag)
          guilds << Guild.where(tag: second_team_tag).first_or_create(name: second_team_tag)

          puts "Importing round #{round}, match number #{number_on_round}, #{first_team_tag} vs #{second_team_tag}"

          json = JSON.parse(content)
          json['parties'].each_with_index do |party, index|
            team = Team.create(
              guild: guilds[index],
              match: match
            )

            party['members'].each do |member|
              igname = member['name'].split(' ')
              igname.pop
              igname = igname.drop(1).join(' ')

              profession = Profession.find_by(profession_id: member['primary'])
              secondary_profession = Profession.find_by(profession_id: member['secondary'])

              position = member['party_index']

              character = Character.where(igname: igname).first_or_create!(
                profession: profession
              )

              player = Player.find_by(igname: igname)
              unless player
                player = Player.where(email: 'default@gwrank.com').first_or_create(
                  password: Devise.friendly_token[0, 20],
                  igname: 'Gwrank Com'
                )
              end

              team_player = TeamPlayer.create!(
                team: team,
                player: player,
                character: character,
                igname: igname,
                profession: profession,
                secondary_profession: secondary_profession,
                position: position
              )

              member['skills'].each do |gw_skill|
                skill_name = gw_skill['name']
                skill = Skill.find_by(name: skill_name)
                unless skill
                  skill_table = skill_name.split(' ')
                  skill_table.pop
                  skill_name = skill_table.join(' ')
                  skill = Skill.find_by(name: skill_name)
                end

                team_player_skill = TeamPlayerSkill.create!(
                  team_player: team_player,
                  skill: skill
                )
              end

              member['stats'].each do |stat_key, stat_value|
                team_player_stat = TeamPlayerStat.create!(
                  team_player: team_player,
                  stat_key: stat_key,
                  stat_value: stat_value
                )
              end
            end
          end
        end
      end
    end
  end
end
