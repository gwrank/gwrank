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
    team_player_skills.each do |team_player_skill|
      skills << team_player_skill.skill.html_image
    end
    skills.join
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
    skills = team_player_skills.joins(:skill).pluck('skills.template_skill_id').first(8)
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
