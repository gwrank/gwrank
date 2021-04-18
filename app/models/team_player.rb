class TeamPlayer < ApplicationRecord
  belongs_to :team
  belongs_to :player
  belongs_to :profession
  belongs_to :secondary_profession, class_name: 'Profession', optional: true
  has_many :team_player_skills, dependent: :destroy
  has_many :team_player_stats, dependent: :destroy

  def skills_text
    skills = []
    team_player_skills.each do |team_player_skill|
      skills << team_player_skill.skill.name
    end
    skills.join('<br>')
  end

  def stats_text
    stats = []
    team_player_stats.each do |team_player_stat|
      stats << "#{team_player_stat.stat_key.humanize}: #{team_player_stat.stat_value}"
    end
    stats.join('<br>')
  end
end
