# frozen_string_literal: true

module GW
  class TemplateReader
    Template = {14 => 'Skills'}
    Profession = %w[None Warrior Ranger Monk Necromancer Mesmer Elementalist Assassin Ritualist Paragon Dervish]
    # Attributes = File.read(File.join(File.dirname(__FILE__), 'code_attributes.txt')).split("\n")
    # Skills     = File.read(File.join(File.dirname(__FILE__), 'code_skills.txt'    )).split("\n")
    Base64Map  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

    attr_reader(:code, :template, :version, :primary, :secondary, :attributes, :skills)

    def initialize(code)
      if template_valid?(code)
        @code = code.dup.freeze
      else
        @code = 'OAAAAAAAAAAAAAAA'.freeze
      end
      @data = decode64(@code)

      @template  = extract!(4)
      @version   = extract!(4)
      bits_pro   = extract!(2) * 2 + 4
      @primary   = extract!(bits_pro)
      @secondary = extract!(bits_pro)

      attrs      = extract!(4)
      bits_att   = extract!(4) + 4
      @attributes = []
      attrs.times {
        @attributes << [extract!(bits_att), extract!(4)]
      }

      bits_ski = extract!(4) + 8
      @skills = []
      8.times {
        @skills << extract!(bits_ski)
      }
    end

    def display o = $stdout
      o.puts("*   Template: #{Template[template]}")
      o.puts("*    Version: #{version}")
      o.puts("*       Code: #{code}")
      o.puts("* Profession: #{Profession[primary]} /" \
                          " #{Profession[secondary]}")
      o.puts
      o.puts("* Attributes:")
      o.puts
      @attributes.each{ |attribute|
        o.puts("  - %20s %2d" % [attribute.first, attribute.last])
      }
      o.puts
      o.puts("* Skills:")
      o.puts
      8.times{ |i|
        o.puts("  - %23s" % @skills[i])
      }
    end


    private

    def template_valid?(code)
      code.chars.all? { |c| Base64Map.include? c }
    end

    def decode64(code)
      code.chars.map{ |char| ('%06d' % Base64Map.index(char).to_s(2)).reverse }.join
    end

    def extract!(n)
      @data.slice!(0, n).reverse.to_i(2)
    end
  end
end

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
    ROUNDS_MAP = [1, 2, 3, 4]
    years = Dir.children(Rails.root.join('data', 'observer'))
    years.each do |year|
      months = Dir.children(Rails.root.join('data', 'observer', year))
      months.each do |month|
        if year.to_i.eql?(2021) && month.to_i < 5
          files = Dir.children(Rails.root.join('data', 'observer', year, month))
          tournament = Tournament.find_by(year: year, month: month)
          next if tournament.present?
          tournament = Tournament.create(year: year, month: month, tournament_type: 'mat')

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
                    password: Devise.friendly_token[0, 20]
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
        else
          files = Dir.children(Rails.root.join('data', 'observer', year, month))
          tournament = Tournament.find_by(year: year, month: month)
          next if tournament.present?
          tournament = Tournament.where(year: year, month: month, tournament_type: 'mat').first_or_create!

          files.each do |filename|
            content = File.read(Rails.root.join('data', 'observer', year, month, filename))

            filename_table = filename.split('.')[0].split('-')
            round_from_final = filename_table[0]
            round = ROUNDS_MAP.reverse[round_from_final.to_i - 1]
            number_on_round = filename_table[1]

            teams_list = filename_table[2].split('_vs_')

            first_team_table = teams_list[0].split('_')
            first_team_name = first_team_table[0..-2].join(' ')
            first_team_tag = first_team_table[-1][1..-2]

            second_team_table = teams_list[1].split('_')
            second_team_name = second_team_table[0..-2].join(' ')
            second_team_tag = second_team_table[-1][1..-2]

            match = Match.where(
              tournament: tournament,
              round: round,
              number_on_round: number_on_round,
            ).first_or_create!

            guilds = []
            guilds << Guild.where(name: first_team_name, tag: first_team_tag).first_or_create!
            guilds << Guild.where(name: second_team_name, tag: second_team_tag).first_or_create!

            puts "Importing round #{round}, match number #{number_on_round}, #{first_team_tag} vs #{second_team_tag}"

            json = JSON.parse(content)
            json['parties']['by_id'].each_with_index do |party, index|
              team = Team.where(
                guild: guilds[index],
                match: match
              ).first_or_create!

              agent_ids = party[1]['agent_ids']
              agent_ids.each do |agent_id|
                agent = json['agents']['by_id']["#{agent_id}"]

                igname = agent['sanitized_name']
                profession = Profession.find_by(profession_id: agent['primary'])
                secondary_profession = Profession.find_by(profession_id: agent['secondary'])
                position = agent['party_index']

                character = Character.where(igname: igname).first_or_create!(profession: profession)

                player = character.player
                unless player
                  player = Player.where(email: 'default@gwrank.com').first_or_create!(
                    password: Devise.friendly_token[0, 20]
                  )
                end

                team_player = TeamPlayer.where(
                  team: team,
                  player: player,
                  character: character,
                  igname: igname,
                  profession: profession,
                  secondary_profession: secondary_profession,
                  position: position
                ).first_or_create!

                agent['stats']['skill_ids_used'].each do |skill_id|
                  skill = Skill.where(skill_id: skill_id).first_or_create!

                  team_player_skill = TeamPlayerSkill.where(
                    team_player: team_player,
                    skill: skill
                  ).first_or_create!
                end

                unless team_player.team_player_skills.count.eql?(8)
                  no_skill = Skill.find_by(skill_id: 0)
                  count = team_player.team_player_skills.count
                  (8 - count).times do |index|
                    TeamPlayerSkill.create!(
                      team_player: team_player,
                      skill: no_skill
                    )
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  task import_from_gw_memorial: :environment do
    files = Dir.children(Rails.root.join('data', 'gw-memorial'))
    files.each do |file_name|
      file_path = Rails.root.join('data', 'gw-memorial', file_name)
      parsed_data = Nokogiri::HTML.parse(file_path)

      mat_infos = parsed_data.css('li.mAT_infos')
      if mat_infos.count.eql?(3)
        date = mat_infos[0].text.gsub('Date: ', '').to_date
        year = date.year
        month = date.month
        guild_number = mat_infos[1].text.gsub('Number of Guilds: ', '').to_i
        map_rotation = mat_infos[2].text.gsub('Map rotation: ', '').to_s
      end

      tournament = Tournament.where(year: year, month: month).first_or_create!
      tournament.update(
        date: date,
        map_rotation: map_rotation,
        guild_number: guild_number
      )

      listing = parsed_data.xpath("//div[@id='resu_finalstandings']")
      final_standings = parsed_data.css('div#resu_finalstandings')
      final_standings.each_with_index do |final_standing, index|
        if index.eql?(0) && final_standings.count.eql?(2)
          round = 1
        elsif final_standings.count.eql?(1) || index.eql?(1)
          round = 2
        end
        final_standing.css('div#resu_listing').each do |table|
          position = table.css('div#resu_table_position').text.gsub('.', '').to_i
          table_cape = table.css('div#resu_table_cape')
          if table_cape.to_s.include?('Gold')
            trim = 1
          elsif table_cape.to_s.include?('Silver')
            trim = 2
          elsif table_cape.to_s.include?('Bronze')
            trim = 3
          end
          region = table.css('div#resu_table_region').attr('class').to_s.gsub('flag', '')
          guild_name = table.css('div#resu_table_guilds').text
          guild_tag = table.css('div#resu_table_tag').text

          guild = Guild.where(name: guild_name).first_or_create!(
            tag: guild_tag,
            region: region,
            is_archived: true
          )
          tournament_result = TournamentResult.where(
            tournament: tournament,
            round: round,
            position: position
          ).first_or_create!(
            trim: trim,
            guild: guild
          )
        end
      end
    end
  end

  task make_them_monthly: :environment do
    Tournament.all.update_all(tournament_type: 'mat')
  end

  task import_from_memorial: :environment do
    content = File.read(Rails.root.join('storage', 'memorial.json'))
    json = JSON.parse(content)
    json.each do |json_match|
      year = json_match['year']
      month = json_match['month']
      day = json_match['day']
      date = Date.parse("#{year}-#{month}-#{day}")

      match_type = json_match['type']

      case match_type.downcase
      when 'playoffs'
        round = 1
      when 'quarter-finals'
        round = 2
      when 'semi-finals'
        round = 3
      when 'finals'
        round = 4
      else
        round = 0
      end

      if match_type.downcase.in?(['swiss rounds', 'playoffs', 'quarter-finals', 'semi-finals', 'finals'])
        tournament = Tournament.where(year: year, month: month).first_or_create!(
          date: date,
          tournament_type: 'mat'
        )
      elsif match_type.downcase.eql?('automated tournaments')
        tournament = Tournament.where(year: year, month: month).first_or_create!(
          date: date,
          tournament_type: 'at'
        )
      else
        puts "Ignored match cause of unknown match type: #{match_type}"
        next
      end

      memorial_match_id = json_match['id']
      match = Match.where(memorial_match_id: memorial_match_id)
      next if match.present?
      match = Match.where(memorial_match_id: memorial_match_id).first_or_create!(
        tournament: tournament,
        round: round
      )

      puts "Importing match #{match.id}..."

      (1..2).each do |team_index|
        guild_name_key = "guild#{team_index}_name"
        guild_tag_key = "guild#{team_index}_tag"
        guild_name = json_match[guild_name_key]
        guild_tag = json_match[guild_tag_key]
        guild_name = '?' if guild_name.empty?
        guild_tag = '?' if guild_tag.empty?

        guild_name = guild_name.titleize

        guild = Guild.where(name: guild_name).first_or_create!(
          tag: guild_tag,
          is_archived: true
        )
        team = Team.create(
          guild: guild,
          match: match
        )

        if json_match['winner'].to_i.eql?(team_index)
          match.update(winner_team: team)
        else
          match.update(loser_team: team)
        end

        (1..8).each do |character_index|
          igname_key = "guild#{team_index}_name#{character_index}"
          igname = json_match[igname_key]
          if igname.end_with?(']')
            igname = igname.split(' ')
            igname.pop
            igname = igname.join(' ')
          end

          template_key = "guild#{team_index}_build#{character_index}"
          template = json_match[template_key]

          base64map  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

          template_reader = GW::TemplateReader.new(template)

          profession = Profession.where(profession_id: template_reader.primary).first_or_create!(
            name: 'Unknown'
          )
          secondary_profession = Profession.where(profession_id: template_reader.secondary).first_or_create!(
            name: 'Unknown'
          )

          position = character_index

          character = Character.where(igname: igname).first_or_create!(
            profession: profession
          )

          player = Player.find_by(igname: igname)
          unless player
            player = Player.where(email: 'default@gwrank.com').first_or_create(
              password: Devise.friendly_token[0, 20]
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

          template_reader.skills.each do |skill_id|
            skill = Skill.where(skill_id: skill_id).first_or_create!(
              name: 'No Skill',
              template_skill_id: skill_id
            )

            TeamPlayerSkill.create!(
              team_player: team_player,
              skill: skill
            )
          end

          unless team_player.team_player_skills.count.eql?(8)
            no_skill = Skill.find_by(skill_id: 0)
            count = team_player.team_player_skills.count
            (8 - count).times do |index|
              TeamPlayerSkill.create!(
                team_player: team_player,
                skill: no_skill
              )
            end
          end
        end
      end
    end
  end
end
