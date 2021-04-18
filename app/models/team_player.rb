class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :player
  belongs_to :profession
  belongs_to :secondary_profession, class_name: 'Profession', optional: true
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
end
