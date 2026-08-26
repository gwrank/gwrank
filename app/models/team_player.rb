# == Schema Information
#
# Table name: team_players
#
#  id                      :bigint           not null, primary key
#  igname                  :string
#  is_captain              :boolean          default(FALSE)
#  position                :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  character_id            :bigint
#  player_id               :bigint           not null
#  profession_id           :bigint
#  secondary_profession_id :integer
#  team_id                 :bigint           not null
#
# Indexes
#
#  index_team_players_on_character_id           (character_id)
#  index_team_players_on_player_id              (player_id)
#  index_team_players_on_player_id_and_team_id  (player_id,team_id)
#  index_team_players_on_profession_id          (profession_id)
#  index_team_players_on_team_id                (team_id)
#  index_team_players_on_team_id_and_player_id  (team_id,player_id)
#
# Foreign Keys
#
#  fk_rails_...  (character_id => characters.id)
#  fk_rails_...  (player_id => players.id)
#  fk_rails_...  (profession_id => professions.id)
#  fk_rails_...  (team_id => teams.id)
#

class TeamPlayer < ApplicationRecord
  belongs_to :character, optional: true
  belongs_to :player
  belongs_to :profession
  belongs_to :secondary_profession, class_name: 'Profession', optional: true
  belongs_to :team
  has_many :team_player_skills, dependent: :destroy
  has_many :team_player_stats, dependent: :destroy

  def anonymized_igname
    "Team Player ##{id || '??'}"
  end

  def anonymized_igname_with_profession(user = nil)
    anonymized_name = anonymized_name_for(user)
    if profession.present?
      "#{anonymized_name} (#{profession.name})"
    else
      anonymized_name
    end
  end

  # Get anonymized display name for a specific user
  # @param user [Player, nil] The user viewing the character
  # @return [String] The anonymized name or original for admins
  def anonymized_name_for(user)
    public_anonymous_label
  end

  def average_dpm
    average_dpm = team_player_stats.find_by(stat_key: "average_dpm")
    return unless average_dpm
    average_dpm.stat_value
  end

  # Placeholder for unauthenticated users
  # @return [String]
  def public_anonymous_label
    "Team Player ##{id}"
  end

  def total_kills
    total_kills = team_player_stats.find_by(stat_key: "total_kills")
    return unless total_kills
    total_kills.stat_value
  end

  def total_deaths
    total_deaths = team_player_stats.find_by(stat_key: "total_deaths")
    return unless total_deaths
    total_deaths.stat_value
  end

  def total_damage_dealt
    total_damage = team_player_stats.find_by(stat_key: "total_damage_dealt")
    return unless total_damage
    total_damage.stat_value
  end

  REZ_SIGNET_NAMES = ['Resurrection Signet', 'Death Pact Signet', 'Death Pact Signet (PvP)', 'Flesh of My Flesh (PvP)'].freeze

  def html_skills
    ordered_skills = build_bar_ordered_skills
    ordered_skills.each_with_index do |team_player_skill, index|
      team_player_skill.update(position: index + 1)
    end
    skills = ordered_skills.map.with_index do |team_player_skill, index|
      image = team_player_skill.skill.html_image
      index.eql?(7) ? "#{image}<br>" : image
    end
    if ordered_skills.count < 8
      (8 - ordered_skills.count).times do
        skills << ActionController::Base.helpers.image_tag('skills/transparent.png', data: { controller: 'tooltip', bs_toggle: 'tooltip', bs_placement: 'bottom' }, title: 'Unknown', width: 55)
      end
    end
    skills.join
  end

  def html_skills_simple
    skills = []
    team_player_skills.includes(:skill).order(position: :asc, id: :asc).each do |team_player_skill|
      skills << team_player_skill.skill.html_image_simple(size: 32)
    end
    if team_player_skills.count < 8
      (8 - team_player_skills.count).times do
        skills << ActionController::Base.helpers.image_tag('skills/transparent.png', title: 'Unknown', width: 32, loading: 'lazy')
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
    Gw1::TemplateCode.new(
      primary_profession_id: profession.profession_id,
      secondary_profession_id: secondary_profession&.profession_id,
      skill_ids: team_player_skills.joins(:skill).order(position: :asc, "team_player_skills.id": :asc).pluck("skills.template_skill_id")
    ).call
  end

  # Get the display name for this team player (from character)
  def igname
    character&.igname
  end

  # Get anonymized name for this team player
  def anonymized_name_for(user)
    character&.anonymized_name_for(user) || igname
  end

  # Get original igname for internal matching (e.g., matching with agent data)
  # This always returns the original name, not anonymized
  def igname_for_matching
    character&.igname
  end

  private

  # Canonical build bar layout: elites first, then primary profession skills,
  # secondary profession skills, any other profession skills, rez signets last.
  # Groups keep creation (id) order so the result is fully deterministic.
  def build_bar_ordered_skills
    skills = team_player_skills.includes(:skill).order(:id).to_a
    elites, skills = skills.partition { |team_player_skill| team_player_skill.skill.is_elite? }
    rez_signets, skills = skills.partition { |team_player_skill| team_player_skill.skill.name.in?(REZ_SIGNET_NAMES) }
    primaries, skills = skills.partition { |team_player_skill| team_player_skill.skill.profession_id == profession_id }
    secondaries, others = skills.partition { |team_player_skill| team_player_skill.skill.profession_id == secondary_profession_id }
    elites + primaries + secondaries + others + rez_signets
  end
end
