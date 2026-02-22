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
    teams.includes(:guild).each do |team|
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

    date = match.imported_at.to_date
    year = date.year
    month = date.month

    match.tournament = Tournament.where(
      year: year,
      month: month,
      date: date,
      tournament_type: "at"
    ).first_or_create!

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
          team_player.team_player_skills.create!(skill: skill)
        end
      end
    end

    match.save!
    match
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
<<<<<<< HEAD
  
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
    morale_boosts = extract_morale_boost_events
    
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
  def extract_morale_boost_events
    return [] unless json.present?
    
    events = []
    parties = json.dig("parties", "by_id") || {}
    
    parties.each do |party_id, party|
      next unless party["morale_boosts"].present?
      
      party["morale_boosts"].each do |boost_event|
        events << {
          timestamp_ms: boost_event["timestamp_ms"],
          party_id: party_id.to_i
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
              
              # Reduce DP by 2% for this living teammate (including killer)
              new_penalty = teammate_data[:penalty] + 2
              # Kill rewards can only reduce DP to 0, cannot boost morale (go positive)
              new_penalty = [new_penalty, 0].min
              teammate_data[:penalty] = new_penalty
              teammate_data[:events] << {
                timestamp_ms: event[:timestamp_ms],
                penalty: new_penalty
              }
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
    party1_morale = calculate_party_morale_timeline(1, player_death_penalty)
    party2_morale = calculate_party_morale_timeline(2, player_death_penalty)
    
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
  
  private
  
  def calculate_party_morale_timeline(party_id, player_death_penalty)
    # Get all players in this party
    party_players = player_death_penalty.select { |_, data| data[:party_id] == party_id }
    return [] if party_players.empty?
    
    # Collect all timestamps across all players
    all_timestamps = party_players.flat_map { |_, data| data[:events].map { |e| e[:timestamp_ms] } }.uniq.sort
    
    # Create step-function timeline with constant values between events
    timeline = []
    previous_avg = 0
    
    # Start at 0%
    timeline << { x: 0, y: 0 }
    
    all_timestamps.each do |timestamp|
      # Calculate average penalty at this timestamp
      penalties = party_players.map do |agent_id, data|
        relevant_events = data[:events].select { |e| e[:timestamp_ms] <= timestamp }
        relevant_events.last[:penalty]
      end
      
      avg_penalty = penalties.sum / penalties.length.to_f
      
      # If value changed, add point at previous value just before this timestamp
      # This creates the "step" effect
      if avg_penalty != previous_avg && timeline.length > 0
        # Add a point 1ms before the change with the old value (creates horizontal line)
        timeline << { x: timestamp - 1, y: previous_avg.round(2) }
      end
      
      # Add point at new value
      timeline << { x: timestamp, y: avg_penalty.round(2) }
      previous_avg = avg_penalty
    end
    
    # Sample if too many points (but keep step structure)
    max_points = 500
    if timeline.length > max_points
      sample_rate = (timeline.length / max_points.to_f).ceil
      timeline = timeline.each_with_index.select { |_, i| i % sample_rate == 0 }.map(&:first)
    end
    
    timeline
  end
end
