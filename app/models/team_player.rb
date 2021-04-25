class TeamPlayer < ApplicationRecord
  belongs_to :character, optional: true
  belongs_to :player
  belongs_to :profession
  belongs_to :secondary_profession, class_name: 'Profession', optional: true
  belongs_to :team
  has_many :team_player_skills, dependent: :destroy
  has_many :team_player_stats, dependent: :destroy

  def html_skills
    skills = []
    unless team_player_skills.first.position.present?
      secondary_profession_skills = []
      other_skills = []
      i = 2
      team_player_skills.each do |team_player_skill|
          if team_player_skill.skill.is_elite?
            position = 1
          elsif team_player_skill.skill.name.in?(['Resurrection Signet', 'Death Pact Signet', 'Death Pact Signet (PvP)', 'Flesh of My Flesh (PvP)'])
            position = 8
          else
            position = i
            i += 1
          end
          if team_player_skill.skill.profession_id.eql?(team_player_skill.team_player.profession_id)
            team_player_skill.update(
              position: position
            )
          elsif team_player_skill.skill.profession_id.eql?(team_player_skill.team_player.secondary_profession_id)
            secondary_profession_skills << team_player_skill
          else
            other_skills << team_player_skill
          end
      end
      secondary_profession_skills.each do |secondary_profession_skill|
        secondary_profession_skill.update(
          position: i
        )
        i += 1
      end
      i += 1
      other_skills.each do |other_skill|
        if other_skill.skill.name.in?(['Resurrection Signet', 'Death Pact Signet', 'Death Pact Signet (PvP)', 'Flesh of My Flesh (PvP)'])
          position = 8
        else
          position = i
        end
        other_skill.update(
          position: position
        )
        i += 1
      end
    end
    team_player_skills.order(position: :asc).each_with_index do |team_player_skill, index|
      skills << team_player_skill.skill.html_image
      skills << '<br>' if index.eql?(7)
    end
    if team_player_skills.count < 8
      (8 - team_player_skills.count).times do
        skills << ActionController::Base.helpers.image_tag('skills/Unknown_Junundu_Ability.jpg', data: { toggle: 'tooltip', placement: 'bottom', 'original-title': 'Unknown' }, width: 42)
      end
    end
    skills.join
  end

  def professions_text
    [profession.name, secondary_profession.name].join('/')
  end

  def stats_text
    stats = []
    team_player_stats.each do |team_player_stat|
      stats << "#{team_player_stat.stat_key.humanize}: #{team_player_stat.stat_value}"
    end
    stats.join('<br>')
  end

  def template_code
    template_type = 14
    version_number = 0
    profession_code = 0 # bits_per_profession_id = code * 2 + 4
    primary_profession = profession.profession_id
    secondary_profession = self.secondary_profession.profession_id
    attributes_count = 0
    attributes_code = 0 # bits_per_attribute_id = code + 4
    skills_code = 4 # bits_per_skill_id = code + 8
    skills = team_player_skills.joins(:skill).order(position: :asc).pluck('skills.template_skill_id').first(8)
    tail = 0

    binary = ("%04b" % template_type).reverse
    binary << ("%04b" % version_number).reverse
    binary << ("%02b" % profession_code).reverse
    binary << ("%04b" % primary_profession).reverse
    binary << ("%04b" % secondary_profession).reverse
    binary << ("%04b" % attributes_count).reverse
    binary << ("%04b" % attributes_code).reverse
    binary << ("%04b" % skills_code).reverse
    skills.each do |skill|
      binary << ("%12b" % skill).reverse
    end
    binary << ("%01b" % tail).reverse
    binary = binary.gsub(' ', '0')
    (180 - binary.length).times { |i| binary << '0' }
    base64map = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    binary.scan(/.{1,6}/).map { |character| base64map[character.reverse.to_i(2)] }.join
  end
end
