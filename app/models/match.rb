# == Schema Information
#
# Table name: matches
#
#  id                :bigint           not null, primary key
#  exported_at       :datetime
#  imported_at       :datetime
#  json              :jsonb
#  name              :string
#  number_on_round   :integer
#  played_at         :datetime
#  round             :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  imported_by_id    :bigint
#  loser_team_id     :integer
#  memorial_match_id :integer
#  tournament_id     :bigint
#  winner_team_id    :integer
#
# Indexes
#
#  index_matches_on_imported_by_id  (imported_by_id)
#  index_matches_on_tournament_id   (tournament_id)
#
# Foreign Keys
#
#  fk_rails_...  (imported_by_id => players.id)
#  fk_rails_...  (tournament_id => tournaments.id)
#

class Match < ApplicationRecord
  belongs_to :imported_by, class_name: 'Player', optional: true
  belongs_to :loser_team, class_name: 'Team', optional: true
  belongs_to :tournament, optional: true
  belongs_to :winner_team, class_name: 'Team', optional: true

  has_one_attached :json_file

  has_many :comments, as: :commentable
  has_many :movies, as: :movieable
  has_many :teams, dependent: :destroy
  has_many :team_players, through: :teams

  def title
    title = []
    teams.each do |team|
      title << team.guild.name_with_tag
    end
    title.join(' vs. ')
  end

  def round_text
    case round
    when 1
      'Playoff'
    when 2
      'Quarterfinal'
    when 3
      'Semifinal'
    when 4
      'Final'
    end
  end

  def self.import!(match_params)
    match = Match.new(match_params)
    match.json = JSON.parse(match_params[:json_file].read)
    match.save!

    match.tournament = Tournament.first_or_create!(
      year: year,
      month: month,
      date: date,
      tournament_type: "at"
    )

    match.json.dig("parties", "by_id").each do |_id, party|
      guild_name = party.dig("name") # e.g.: "Le Poulpe Divin"
      guild_display_name = party.dig("display_name") # e.g.: "Le Poulpe Divin [KrkN]"
      guild_tag = guild_display_name.split("[").last.split("]").first
      guild_rank = party.dig("rank")
      guild_rating = party.dig("rating")

      guild = Guild.where(name: guild_name, tag: guild_tag).first_or_create!
      team = match.teams.create!(guild: guild, rank: guild_rank, rating: guild_rating)

      is_victorious = party.dig("is_victorious")
      match.winner_team = team if is_victorious

      is_defeated = party.dig("is_defeated")
      match.loser_team = team if is_defeated


      agent_ids = party.dig("agent_ids")
      agent_ids.each do |agent_id|
        agent = match.json.dig("agents", "by_id")[agent_id.to_s]

        igname = agent.dig("sanitized_name") # e.g.: Divin Arkalon
        primary = agent.dig("primary") # e.g.: 3
        profession = Profession.find_by(profession_id: primary)
        secondary = agent.dig("secondary") # e.g.: 7
        secondary_profession = Profession.find_by(profession_id: secondary)
        position = agent.dig("display_name").split(")").first.split("(").second

        character = Character.first_or_create!(igname:) do |c|
          c.profession = profession
        end

        player = character.player
        player ||= Player.first_or_create!(igname:) do |p|
          p.email = igname.split.join("-").downcase + "@gwrank.com"
          p.password = Devise.friendly_token[0, 20]
        end

        team_player = team.team_players.create!(
          player: player,
          character: character,
          igname: igname,
          profession: profession,
          secondary_profession: secondary_profession,
          position: position
        )

        skill_ids = agent.dig("stats", "skill_ids_used").each do |skill_id|
          skill = Skill.find_by(skill_id: skill_id)
          team_player.team_player_skills.create!(skill: skill)
        end
      end
    end

    match.save!
    match
  end
end
