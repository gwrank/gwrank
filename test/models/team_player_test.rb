require 'test_helper'

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
class TeamPlayerTest < ActiveSupport::TestCase
  test 'html_skills assigns build bar slots deterministically regardless of heap order' do
    team_player = create_team_player_with_skills

    expected = [
      'Agonizing Chop',       # elite -> slot 1
      'Sprint',               # primary, created first -> slot 2
      'Hammer Bash',          # primary, created second -> slot 3
      'Example Ward',         # secondary profession -> slot 4
      'Water Attunement',     # other profession -> slot 5
      'Air Attunement',       # other profession -> slot 6
      'Resurrection Signet',  # rez signet -> slot 8
      'Unknown'               # filler
    ]
    assert_equal expected, rendered_skill_titles(team_player)

    # Touching rows rewrites their heap tuples: iteration order must not matter
    team_player.team_player_skills.order(:id).first.touch
    assert_equal expected, rendered_skill_titles(team_player.reload)
  end

  test 'html_skills is stable across consecutive renders' do
    team_player = create_team_player_with_skills
    first_render = rendered_skill_titles(team_player)
    second_render = rendered_skill_titles(team_player.reload)
    assert_equal first_render, second_render
  end

  test 'skills sharing a position are ordered by id' do
    team_player = create_team_player(professions(:warrior), professions(:monk))
    add_skill(team_player, name: 'Agonizing Chop', is_elite: true, profession: professions(:warrior), skill_id: 900_001)
    add_skill(team_player, name: 'Coward!', is_elite: true, profession: professions(:warrior), skill_id: 900_002)

    assert_equal ['Agonizing Chop', 'Coward!'] + ['Unknown'] * 6, rendered_skill_titles(team_player)
  end

  private

  def create_team_player(primary, secondary)
    match = create_match
    match.teams.first.team_players.create!(
      player: create_player,
      position: 1,
      profession: primary,
      secondary_profession: secondary
    )
  end

  def create_team_player_with_skills
    team_player = create_team_player(professions(:warrior), professions(:monk))
    add_skill(team_player, name: 'Sprint', skill_type: 'Skill', profession: professions(:warrior), skill_id: 900_011)
    add_skill(team_player, name: 'Hammer Bash', skill_type: 'Skill', profession: professions(:warrior), skill_id: 900_012)
    add_skill(team_player, name: 'Agonizing Chop', skill_type: 'Elite Sword Attack', is_elite: true, profession: professions(:warrior), skill_id: 900_013)
    add_skill(team_player, name: 'Example Ward', skill_type: 'Spell', profession: professions(:monk), skill_id: 900_014)
    add_skill(team_player, name: 'Water Attunement', skill_type: 'Spell', profession: professions(:elementalist), skill_id: 900_015)
    add_skill(team_player, name: 'Air Attunement', skill_type: 'Spell', profession: professions(:elementalist), skill_id: 900_016)
    add_skill(team_player, name: 'Resurrection Signet', skill_type: 'Spell', profession: professions(:monk), skill_id: 900_017)
    team_player
  end

  def add_skill(team_player, name:, skill_type: 'Skill', is_elite: false, profession:, skill_id:)
    Skill.create!(name: name, skill_type: skill_type, is_elite: is_elite, profession: profession, skill_id: skill_id, template_skill_id: skill_id).tap do |skill|
      team_player.team_player_skills.create!(skill: skill)
    end
  end

  def rendered_skill_titles(team_player)
    html = team_player.html_skills
    html.scan(/title="([^"]*)"/).map { |(title)| title.split('.').first }.map { |t| t == 'Unknown' ? 'Unknown' : t }
  end
end
