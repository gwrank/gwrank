# == Schema Information
#
# Table name: matches
#
#  id                :bigint           not null, primary key
#  elo_calculated    :boolean
#  exported_at       :datetime
#  imported_at       :datetime
#  json              :jsonb
#  name              :string
#  number_on_round   :integer
#  played_at         :datetime
#  round             :integer
#  slug              :string
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
  has_many :players, through: :teams
  has_many :team_players, through: :teams

  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged
  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  def prepare_stats!
    return unless json.present?

    json.dig("parties", "by_id").each do |_id, party|
      agent_ids = party.dig("agent_ids")
      agent_ids.each do |agent_id|
        agent = json.dig("agents", "by_id")[agent_id.to_s]
        igname = agent.dig("sanitized_name") # e.g.: Divin Arkalon

        team_player = team_players.find_by(igname: igname)
        next unless team_player

        next unless match_duration_mins = json.dig("match_duration_mins")
        next if match_duration_mins == 0

        primary = agent.dig("primary")
        profession = Profession.find_by(profession_id: primary)

        case profession.name&.downcase
        when 'warrior'
          total_crits_dealt = agent.dig("stats", "total_crits_dealt")
          average_cpm = total_crits_dealt.to_f / match_duration_mins.to_f
          team_player.team_player_stats.where(stat_key: "average_warrior_cpm").first_or_create!(stat_value: average_cpm)
        when 'monk'
          total_healing_dealt = agent.dig("stats", "total_healing_dealt")
        end
      end
    end

    players.find_each(&:prepare_stats!)
    self
  end

  def slug_candidates
    opponents = teams.includes(:guild).map do |team|
      team.guild.slug
    end
    opponents_slug = opponents.join('-vs-')
    tournament.present? ? [tournament.slug, opponents_slug].join('-') : opponents_slug
  end

  def title
    title = []
    teams.includes(:guild).each do |team|
      next unless team.guild
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

  def map_name
    json&.dig('map', 'name')
  end

  def map_id
    json&.dig('map', 'map_id')
  end

  def match_type
    json&.dig('match_type')
  end

  def mat_round
    json&.dig('mat_round')
  end

  def self.import!(match_params)
    match = Match.new(match_params)
    match.json = JSON.parse(match_params[:json_file].read)
    
    # Extract match_date from JSON and set as played_at
    match_date_str = match.json.dig('match_date')
    if match_date_str.present?
      match.played_at = DateTime.parse(match_date_str) rescue match.imported_at
    else
      match.played_at = match.imported_at
    end
    
    match.save!

    # Use match_date for tournament date if available, otherwise fall back to imported_at
    date = match.played_at.to_date
    year = date.year
    month = date.month

    # Extract match_type from JSON to determine tournament type
    match_type_str = match.json.dig('match_type')
    if match_type_str.present?
      # Convert match_type to tournament_type
      # MAT = Monthly Automated Tournament, AT = Automated Tournament
      tournament_type = match_type_str.downcase.include?("mat") ? "mat" : "at"
      # Add tournament region (a, b or c)
      region = match_type_str.split(' ').last.downcase
    end

    match.tournament = Tournament.where(
      year: year,
      month: month,
      date: date,
      region: region,
      tournament_type: tournament_type
    ).first_or_create!

    # Set round from mat_round if it's MAT
    if tournament_type == "mat"
      mat_round_value = match.json.dig('mat_round')
      if mat_round_value.present?
        case mat_round_value.to_s.downcase
        when /playoff/
          match.round = 1
        when /quarter/
          match.round = 2
        when /semi/
          match.round = 3
        when /final/
          match.round = 4
        else
          match.round = mat_round_value.to_i if mat_round_value.to_i > 0
        end
      end
    end

    match.json.dig("parties", "by_id").each do |_id, party|
      guild_name = party.dig("name") # e.g.: "Le Poulpe Divin"
      guild_display_name = party.dig("display_name") # e.g.: "Le Poulpe Divin [KrkN]"
      guild_tag = guild_display_name.split("[").last.split("]").first
      guild_rank = party&.dig("rank")
      guild_rating = party&.dig("rating")

      guild = Guild.where(name: guild_name, tag: guild_tag).first_or_create!
      guild.update!(is_archived: false) unless guild.new_record?
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
        position ||= team.team_players.count + 1

        character = Character.where(igname: igname).first_or_create! do |c|
          c.profession = profession
        end

        player = character.player
        player ||= Player.where(igname: igname).first_or_create! do |p|
          p.username = igname
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
          team_player.team_player_skills.create!(skill: skill) if skill
        end
      end
    end

    match.calculate_elo! if match.winner_team && match.loser_team
    match.save!
    match
  end

  # Calculate ELO ratings for all players in this match
  def calculate_elo!
    return unless winner_team && loser_team

    winner_elo_sum = winner_team.players.where.not(elo_rating: nil).sum(:elo_rating)
    loser_elo_sum = loser_team.players.where.not(elo_rating: nil).sum(:elo_rating)

    winner_avg = winner_team.players.where.not(elo_rating: nil).count > 0 ?
      winner_elo_sum / winner_team.players.where.not(elo_rating: nil).count : 1200
    loser_avg = loser_team.players.where.not(elo_rating: nil).count > 0 ?
      loser_elo_sum / loser_team.players.where.not(elo_rating: nil).count : 1200

    # K-factor: higher for new players, max 32
    k_factor = 32

    winner_team.team_players.each do |team_player|
      player = team_player.player
      next unless player

      player_elo = player.elo_rating || 1200
      player_elo_matches = player.elo_matches || 0

      # Expected score based on ELO difference
      expected_score = 1 / (1 + 10 ** ((loser_avg - player_elo) / 400.0))

      # New ELO = Old ELO + K * (Actual Score - Expected Score)
      # Win = 1 point
      new_elo = (player_elo + k_factor * (1 - expected_score)).round

      player.update(elo_rating: new_elo, elo_matches: player_elo_matches + 1)
    end

    loser_team.team_players.each do |team_player|
      player = team_player.player
      next unless player

      player_elo = player.elo_rating || 1200
      player_elo_matches = player.elo_matches || 0

      # Expected score based on ELO difference
      expected_score = 1 / (1 + 10 ** ((winner_avg - player_elo) / 400.0))

      # Loss = 0 point
      new_elo = (player_elo + k_factor * (0 - expected_score)).round

      player.update(elo_rating: new_elo, elo_matches: player_elo_matches + 1)
    end

    self
  end

  # Recalculate ELO for all matches (for initial ELO setup)
  def self.recalculate_all_elo!
    Player.update_all(elo_rating: nil, elo_matches: 0)

    Match.where.not(winner_team_id: nil).where.not(loser_team_id: nil)
      .order(:played_at, :id).each do |match|
        match.calculate_elo!
      end
  end

  # Memoized player stats to avoid re-parsing JSON
  def player_stats
    @player_stats ||= calculate_player_stats
  end
  
  def calculate_player_stats
    return [] unless json.present?
    
    stats = []
    json.dig("agents", "by_id")&.each do |agent_id, agent|
      next if agent["sanitized_name"].blank?
      next if agent["guild_id"] == 0 # Skip NPCs
      
      stats << {
        agent_id: agent_id,
        name: agent["sanitized_name"],
        profession: agent["profession"],
        party_id: agent["party_id"],
        stats: agent["stats"] || {}
      }
    end
    
    stats.sort_by { |s| [s[:party_id], s[:name]] }
  end

  def team_stats(team_index)
    # Use loaded association instead of querying again
    team = teams[team_index - 1]
    return [] unless team
    
    # Get player stats for this team
    team_player_stats = player_stats.select { |s| s[:party_id] == team_index }
    
    # Create a hash for quick lookup by name
    stats_by_name = team_player_stats.index_by { |s| s[:name] }
    
    # Order by team_player position (already loaded via includes)
    ordered_stats = []
    team.team_players.sort_by(&:position).each do |team_player|
      stat = stats_by_name[team_player.igname]
      ordered_stats << stat if stat
    end
    
    # Add any remaining stats that didn't match (shouldn't happen, but just in case)
    remaining = team_player_stats.reject { |s| ordered_stats.include?(s) }
    ordered_stats + remaining
  end

  # Memoize agent lookups
  def agent_by_id(agent_id)
    @agents_cache ||= {}
    @agents_cache[agent_id.to_s] ||= json.dig("agents", "by_id", agent_id.to_s)
  end
  
  # Calculate NPC kills for a team
  def npc_kills(team_index)
    return 0 unless json.present?
    
    total_kills = 0
    
    # Get all NPCs (guild_id == 0) that were killed
    json.dig("agents", "by_id")&.each do |agent_id, agent|
      next unless agent["guild_id"] == 0 # Only NPCs
      next if agent["stats"].blank?
      
      deaths = agent.dig("stats", "deaths") || 0
      next if deaths == 0
      
      # Check damage dealt to this NPC by team members
      damage_to_npc = 0
      player_stats.select { |s| s[:party_id] == team_index }.each do |player_stat|
        damage_dealt = player_stat[:stats].dig("damage_dealt_to_agents", agent_id) || 0
        damage_to_npc += damage_dealt
      end
      
      # If this team dealt damage to the NPC and it died, count it as a kill
      total_kills += 1 if damage_to_npc > 0 && deaths > 0
    end
    
    total_kills
  end
  
  # Extract health snapshots for graphing
  def health_percentage_data
    return nil unless json.present?
    
    parties = json.dig("parties", "by_id")
    return nil unless parties
    
    team1_data = parties["1"]&.dig("health_snapshots") || []
    team2_data = parties["2"]&.dig("health_snapshots") || []
    
    # Sample data if there are too many points (keep every Nth point for performance)
    # Target approximately 300-500 points for smooth rendering
    max_points = 500
    sample_rate = [(team1_data.length / max_points.to_f).ceil, (team2_data.length / max_points.to_f).ceil, 1].max
    
    team1_sampled = sample_rate > 1 ? team1_data.each_with_index.select { |_, i| i % sample_rate == 0 }.map(&:first) : team1_data
    team2_sampled = sample_rate > 1 ? team2_data.each_with_index.select { |_, i| i % sample_rate == 0 }.map(&:first) : team2_data
    
    # Get team names
    team1_name = parties["1"]&.dig("display_name") || "Team 1"
    team2_name = parties["2"]&.dig("display_name") || "Team 2"
    
    # Get guild wrapped tags
    guilds = json.dig("guilds", "by_id") || {}
    team1_guild_id = parties["1"]&.dig("guild_id")
    team2_guild_id = parties["2"]&.dig("guild_id")
    team1_tag = team1_guild_id ? guilds[team1_guild_id.to_s]&.dig("wrapped_tag") : nil
    team2_tag = team2_guild_id ? guilds[team2_guild_id.to_s]&.dig("wrapped_tag") : nil
    
    # Extract all events
    death_events = extract_death_events
    resurrection_events = extract_resurrection_events
    morale_boosts = extract_morale_boost_events(team1_tag, team2_tag)
    npc_death_events = extract_npc_death_events(team1_tag, team2_tag)
    tower_captures = extract_tower_capture_events(team1_tag, team2_tag)
    shrine_captures = extract_shrine_capture_events(team1_tag, team2_tag)
    
    # Get morale data
    morale_data = party_morale_data
    
    {
      team1: {
        name: team1_name,
        tag: team1_tag,
        data: team1_sampled.map { |snapshot| 
          {
            x: snapshot["timestamp_ms"],
            y: (snapshot["hp_percentage"] * 100).round(2)
          }
        }
      },
      team2: {
        name: team2_name,
        tag: team2_tag,
        data: team2_sampled.map { |snapshot| 
          {
            x: snapshot["timestamp_ms"],
            y: (snapshot["hp_percentage"] * 100).round(2)
          }
        }
      },
      death_events: death_events,
      resurrection_events: resurrection_events,
      morale_boosts: morale_boosts,
      npc_death_events: npc_death_events,
      tower_captures: tower_captures,
      shrine_captures: shrine_captures,
      morale_data: morale_data
    }
  end
  
  # Extract death events from all agents
  def extract_death_events
    return [] unless json.present?
    
    events = []
    agents = json.dig("agents", "by_id") || {}
    
    agents.each do |agent_id, agent|
      next unless agent["death_events"].present?
      
      party_id = agent["party_id"]
      agent_name = agent["sanitized_name"] || agent["display_name"] || "Unknown"
      is_npc = agent["guild_id"] == 0
      
      agent["death_events"].each do |death_event|
        killing_skill_id = death_event["killing_skill_id"]
        killer_agent_id = death_event["killer_agent_id"]
        
        # Check if death was caused by Death Pact
        is_death_pact = killing_skill_id == 0 && killer_agent_id == 0
        
        # Get skill name if available
        killing_skill_name = nil
        if killing_skill_id && killing_skill_id > 0
          skill = Skill.find_by(skill_id: killing_skill_id)
          killing_skill_name = skill&.name
        end
        
        events << {
          timestamp_ms: death_event["timestamp_ms"],
          agent_name: agent_name,
          agent_id: agent_id,
          party_id: party_id,
          is_npc: is_npc,
          killer_agent_id: killer_agent_id,
          killing_skill_id: killing_skill_id,
          killing_skill_name: killing_skill_name,
          is_death_pact: is_death_pact
        }
      end
    end
    
    events.sort_by { |e| e[:timestamp_ms] }
  end
  
  # Extract resurrection events
  def extract_resurrection_events
    return [] unless json.present?
    
    events = []
    agents = json.dig("agents", "by_id") || {}
    
    agents.each do |agent_id, agent|
      next unless agent["resurrection_events"].present?
      next if agent["guild_id"] == 0 # Skip NPCs
      
      party_id = agent["party_id"]
      agent_name = agent["sanitized_name"] || agent["display_name"] || "Unknown"
      
      agent["resurrection_events"].each do |res_event|
        resurrector_agent_id = res_event["resurrector_agent_id"]
        resurrector = resurrector_agent_id ? agents[resurrector_agent_id.to_s] : nil
        resurrector_name = resurrector ? (resurrector["sanitized_name"] || resurrector["display_name"]) : nil
        
        resurrection_skill_id = res_event["resurrection_skill_id"]
        resurrection_skill_name = nil
        if resurrection_skill_id && resurrection_skill_id > 0
          skill = Skill.find_by(skill_id: resurrection_skill_id)
          resurrection_skill_name = skill&.name
        end
        
        events << {
          timestamp_ms: res_event["timestamp_ms"],
          agent_id: agent_id,
          agent_name: agent_name,
          party_id: party_id,
          resurrector_agent_id: resurrector_agent_id,
          resurrector_name: resurrector_name,
          resurrection_skill_id: resurrection_skill_id,
          resurrection_skill_name: resurrection_skill_name,
          is_base_res: resurrector_agent_id.nil? || resurrector_agent_id == 0
        }
      end
    end
    
    events.sort_by { |e| e[:timestamp_ms] }
  end
  
  # Extract morale boost events
  def extract_morale_boost_events(team1_tag = nil, team2_tag = nil)
    return [] unless json.present?
    
    events = []
    parties = json.dig("parties", "by_id") || {}
    
    parties.each do |party_id, party|
      next unless party["morale_boosts"].present?
      
      guild_tag = party_id.to_i == 1 ? team1_tag : team2_tag
      
      party["morale_boosts"].each do |boost_event|
        events << {
          timestamp_ms: boost_event["timestamp_ms"],
          party_id: party_id.to_i,
          guild_tag: guild_tag
        }
      end
    end
    
    events.sort_by { |e| e[:timestamp_ms] }
  end
  
  # Extract tower (flag) capture events
  def extract_tower_capture_events(team1_tag = nil, team2_tag = nil)
    return [] unless json.present?
    
    events = []
    parties = json.dig("parties", "by_id") || {}
    
    parties.each do |party_id, party|
      next unless party["tower_captures"].present?
      
      guild_tag = party_id.to_i == 1 ? team1_tag : team2_tag
      party_name = party["name"] || party["display_name"] || "Team #{party_id}"
      
      party["tower_captures"].each do |capture_event|
        events << {
          timestamp_ms: capture_event["timestamp_ms"],
          party_id: party_id.to_i,
          guild_tag: guild_tag,
          party_name: party_name
        }
      end
    end
    
    events.sort_by { |e| e[:timestamp_ms] }
  end
  
  # Extract shrine capture events
  def extract_shrine_capture_events(team1_tag = nil, team2_tag = nil)
    return [] unless json.present?
    
    events = []
    parties = json.dig("parties", "by_id") || {}
    
    parties.each do |party_id, party|
      next unless party["shrine_captures"].present?
      
      guild_tag = party_id.to_i == 1 ? team1_tag : team2_tag
      party_name = party["name"] || party["display_name"] || "Team #{party_id}"
      
      party["shrine_captures"].each do |capture_event|
        events << {
          timestamp_ms: capture_event["timestamp_ms"],
          party_id: party_id.to_i,
          guild_tag: guild_tag,
          party_name: party_name
        }
      end
    end
    
    events.sort_by { |e| e[:timestamp_ms] }
  end
  
  # Extract NPC death events (filtered to important NPCs only)
  def extract_npc_death_events(team1_tag = nil, team2_tag = nil)
    return [] unless json.present?
    
    events = []
    agents = json.dig("agents", "by_id") || {}
    
    # List of important NPC types we want to track
    important_npcs = ["Archer", "Guild Lord", "Footman", "Knight", "Bodyguard"]
    
    agents.each do |agent_id, agent|
      next unless agent["death_events"].present?
      next unless agent["guild_id"] == 0 # NPCs have guild_id 0
      
      agent_name = agent["sanitized_name"] || agent["display_name"] || "Unknown"
      
      # Skip if not in important NPCs list
      next unless important_npcs.any? { |npc_type| agent_name.include?(npc_type) }
      
      agent["death_events"].each do |death_event|
        killer_agent_id = death_event["killer_agent_id"]
        
        # Determine which team the NPC belongs to by looking at who killed it
        # If killed by team 1, NPC belongs to team 2, and vice versa
        npc_party_id = nil
        npc_tag = nil
        if killer_agent_id && killer_agent_id > 0
          killer = agents[killer_agent_id.to_s]
          if killer && killer["party_id"]
            killer_party = killer["party_id"]
            # NPC belongs to opposite team of killer
            npc_party_id = killer_party == 1 ? 2 : 1
            npc_tag = npc_party_id == 1 ? team1_tag : team2_tag
          end
        end
        
        # Skip if we couldn't determine team ownership
        next unless npc_party_id
        
        events << {
          timestamp_ms: death_event["timestamp_ms"],
          agent_name: agent_name,
          agent_id: agent_id,
          party_id: npc_party_id,
          guild_tag: npc_tag,
          is_npc: true,
          npc_type: important_npcs.find { |npc_type| agent_name.include?(npc_type) }
        }
      end
    end
    
    events.sort_by { |e| e[:timestamp_ms] }
  end
  
  # Calculate party morale over time based on death penalty formula
  # according to https://wiki.guildwars.com/wiki/Death_Penalty
  def party_morale_data
    return nil unless json.present?
    
    parties = json.dig("parties", "by_id")
    return nil unless parties
    
    # Get all events sorted by timestamp
    death_events = extract_death_events.select { |e| !e[:is_npc] } # Only player deaths TODO: check if pets are considered npcs ? 
    resurrection_events = extract_resurrection_events
    morale_boosts = extract_morale_boost_events
    
    # Calculate death penalty for each player over time
    player_death_penalty = {}
    
    # Track last resurrection time for each player
    last_res_time = {}
    
    # Track which players are currently alive
    player_alive_status = {}
    
    # Initialize all players
    agents = json.dig("agents", "by_id") || {}
    agents.each do |agent_id, agent|
      next if agent["guild_id"] == 0 # Skip NPCs
      next if agent["party_id"] == 0 # Skip party 0 (NPCs)
      
      player_death_penalty[agent_id] = {
        party_id: agent["party_id"],
        penalty: 0,
        events: [{timestamp_ms: 0, penalty: 0}]
      }
      player_alive_status[agent_id] = true # Everyone starts alive
    end
    
    # Process all events chronologically
    all_events = []
    death_events.each { |e| all_events << e.merge(type: :death) }
    resurrection_events.each { |e| all_events << e.merge(type: :resurrection) }
    morale_boosts.each { |e| all_events << e.merge(type: :morale_boost) }
    all_events.sort_by! { |e| e[:timestamp_ms] }
    
    all_events.each do |event|
      case event[:type]
      when :death
        agent_id = event[:agent_id]
        next unless player_death_penalty[agent_id]
        
        # Mark player as dead
        player_alive_status[agent_id] = false
        
        # Check if death should be penalized
        should_penalize = true
        
        # Exception: Death Pact (killing_skill_id = 0 and killer_agent_id = 0)
        if event[:killing_skill_id] == 0 && event[:killer_agent_id] == 0
          should_penalize = false
        end
        
        # Exception: Death within 5 seconds of resurrection
        if last_res_time[agent_id] && (event[:timestamp_ms] - last_res_time[agent_id]) < 5000
          should_penalize = false
        end
        
        if should_penalize
          new_penalty = player_death_penalty[agent_id][:penalty] - 15
          # Cap at -60%
          new_penalty = [new_penalty, -60].max
          player_death_penalty[agent_id][:penalty] = new_penalty
          player_death_penalty[agent_id][:events] << {
            timestamp_ms: event[:timestamp_ms],
            penalty: new_penalty
          }
        end
        
        # Check if killer is a player from opposing party (PvP kill)
        killer_agent_id = event[:killer_agent_id]
        if killer_agent_id && killer_agent_id > 0 && player_death_penalty[killer_agent_id.to_s]
          killer_data = player_death_penalty[killer_agent_id.to_s]
          victim_party = player_death_penalty[agent_id][:party_id]
          
          # Only apply bonus if killer and victim are from different parties
          if killer_data[:party_id] != victim_party
            # Apply -2% DP to each living teammate of the killer (including the killer)
            player_death_penalty.each do |teammate_id, teammate_data|
              # Skip if not same party as killer or if dead
              next if teammate_data[:party_id] != killer_data[:party_id]
              next unless player_alive_status[teammate_id]
              
              # Kill rewards only reduce death penalty, not morale boosts
              # Only apply if player has negative penalty (death penalty)
              current_penalty = teammate_data[:penalty]
              if current_penalty < 0
                new_penalty = [current_penalty + 2, 0].min
                teammate_data[:penalty] = new_penalty
                teammate_data[:events] << {
                  timestamp_ms: event[:timestamp_ms],
                  penalty: new_penalty
                }
              end
            end
          end
        end
        
      when :resurrection
        agent_id = event[:agent_id]
        last_res_time[agent_id] = event[:timestamp_ms]
        # Mark player as alive again
        player_alive_status[agent_id] = true
        
      when :morale_boost
        party_id = event[:party_id]
        # Apply +10% to all players in this party
        player_death_penalty.each do |agent_id, data|
          if data[:party_id] == party_id
            new_penalty = data[:penalty] + 10
            # Cap at +10% (max morale boost)
            new_penalty = [new_penalty, 10].min
            data[:penalty] = new_penalty
            data[:events] << {
              timestamp_ms: event[:timestamp_ms],
              penalty: new_penalty
            }
          end
        end
      end
    end
    
    # Calculate average party morale over time
    # Group by party and calculate average at each timestamp
    
    # Get match duration from health snapshots or last event
    match_duration = [
      parties["1"]&.dig("health_snapshots")&.last&.dig("timestamp_ms"),
      parties["2"]&.dig("health_snapshots")&.last&.dig("timestamp_ms"),
      all_events.last&.dig(:timestamp_ms)
    ].compact.max || 0
    
    party1_morale = calculate_party_morale_timeline(1, player_death_penalty, match_duration)
    party2_morale = calculate_party_morale_timeline(2, player_death_penalty, match_duration)
    
    # Get team names
    team1_name = parties["1"]&.dig("display_name") || "Team 1"
    team2_name = parties["2"]&.dig("display_name") || "Team 2"
    
    {
      team1: {
        name: team1_name,
        data: party1_morale
      },
      team2: {
        name: team2_name,
        data: party2_morale
      }
    }
  end
  
  # Extract guild lord damage data for charting
  def guild_lord_damage_data
    return nil unless json.present?
    
    agents = json.dig("agents", "by_id") || {}
    parties = json.dig("parties", "by_id") || {}
    guilds = json.dig("guilds", "by_id") || {}
    
    # Get guild names from teams association (teams[0] is party_id 1, teams[1] is party_id 2)
    team_guilds = {}
    teams.includes(:guild).each_with_index do |team, index|
      party_id = index + 1
      team_guilds[party_id] = team.guild.name_with_tag if team.guild
    end
    
    # Find guild lord agents
    guild_lords = []
    agents.each do |agent_id, agent|
      next unless agent["guild_id"] == 0 # Only NPCs
      agent_name = agent["sanitized_name"] || agent["display_name"] || ""
      next unless agent_name.include?("Guild Lord")
      
      # Get damage received from each agent
      damage_dealers = []
      damage_from_agents = agent.dig("stats", "damage_received_from_agents") || {}
      total_damage = 0
      
      # Determine which party this guild lord belongs to by looking at attackers
      # Guild lords are attacked by the opposite team
      attacker_parties = []
      
      damage_from_agents.each do |attacker_id, damage|
        attacker = agents[attacker_id]
        next unless attacker
        
        total_damage += damage
        attacker_party_id = attacker["party_id"]
        attacker_parties << attacker_party_id if attacker_party_id && attacker_party_id > 0
        
        damage_dealers << {
          agent_id: attacker_id,
          name: attacker["sanitized_name"] || "Unknown",
          profession: attacker["profession"],
          party_id: attacker_party_id,
          damage: damage
        }
      end
      
      # Skip if no damage data or can't determine team
      next if damage_dealers.empty?
      
      # The guild lord belongs to the opposite team of the attackers
      # If attackers are mostly from party 1, the lord is from party 2, and vice versa
      attacking_party = attacker_parties.max_by { |p| attacker_parties.count(p) }
      lord_party_id = attacking_party == 1 ? 2 : 1
      
      guild_id = parties[lord_party_id.to_s]&.dig("guild_id")
      guild_tag = guild_id ? guilds[guild_id.to_s]&.dig("wrapped_tag") : nil
      party_name = parties[lord_party_id.to_s]&.dig("display_name") || "Team #{lord_party_id}"
      
      # Sort by damage descending
      damage_dealers.sort_by! { |d| -d[:damage] }
      
      guild_lords << {
        agent_id: agent_id,
        name: party_name,
        tag: guild_tag,
        party_id: lord_party_id,
        total_damage: total_damage,
        damage_dealers: damage_dealers
      }
    end
    
    return nil if guild_lords.empty?
    
    {
      guild_lords: guild_lords,
      team_guilds: team_guilds
    }
  end
  
  private
  
  def calculate_party_morale_timeline(party_id, player_death_penalty, match_duration)
    # Get all players in this party
    party_players = player_death_penalty.select { |_, data| data[:party_id] == party_id }
    return [] if party_players.empty?
    
    # Collect all unique timestamps across all players
    all_timestamps = party_players.flat_map { |_, data| 
      data[:events].map { |e| e[:timestamp_ms] }
    }.uniq.sort
    
    # Always start at timestamp 0 with morale 0
    timeline = [{ x: 0, y: 0 }]
    previous_avg = 0
    
    all_timestamps.each do |timestamp|
      # Skip timestamp 0 since we already added it
      next if timestamp == 0
      
      # Calculate average penalty at this timestamp for all players in this party
      penalties = party_players.map do |agent_id, data|
        # Find the penalty value for this player at this exact timestamp
        # by getting the last event that occurred at or before this timestamp
        relevant_events = data[:events].select { |e| e[:timestamp_ms] <= timestamp }
        relevant_events.last[:penalty]
      end
      
      avg_penalty = penalties.sum / penalties.length.to_f
      
      # Add point at this timestamp with the current average
      # Only add if different from previous point (avoid duplicate consecutive values)
      if (previous_avg - avg_penalty).abs > 0.001
        timeline << { x: timestamp, y: avg_penalty.round(2) }
        previous_avg = avg_penalty
      end
    end
    
    # Add final point at match duration to extend the stepped line
    if timeline.any? && match_duration > 0 && timeline.last[:x] < match_duration
      timeline << { x: match_duration, y: timeline.last[:y] }
    end
    
    timeline
  end
end
