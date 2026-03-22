class MatchesController < ApplicationController
  before_action :authenticate_player!, only: [:new, :create, :destroy]
  before_action :set_match, only: [:destroy]
  before_action :ensure_player_is_moderator_and_importer, only: [:destroy]

  def index
    @pagy, @matches = pagy(Match.includes(teams: [:guild, { team_players: [:profession, :secondary_profession, { team_player_skills: :skill }] }]).order(played_at: :desc), limit: 4)
  end

  def show
    @match = Match.includes(
      comments: [:player],
      teams: [
        :guild,
        { team_players: [:character, :player, :profession, :secondary_profession, :team_player_skills] }
      ]
    ).friendly.find(params[:id])
    
    # Preload all skills that might be used in stats
    @skills_cache = preload_skills_for_match if @match.json.present?
    
    @comment = Comment.new
    @movie = Movie.new

    respond_to do |format|
      format.html
    end
  end

  def new
    @match = Match.new
  end

  def create
    @match = Match.import!(match_params)
    redirect_to match_path(@match)
  end

  def destroy
    @match.destroy
    redirect_to matches_path
  end

  private

  def ensure_player_is_moderator_and_importer
    current_player&.is_moderator? && current_player.eql?(@match.imported_by)
  end
  
  def preload_skills_for_match
    # Extract all skill IDs from the match JSON
    skill_ids = []
    @match.json.dig("agents", "by_id")&.each do |_agent_id, agent|
      # Get skills from damage_by_skill (damage-dealing skills)
      damage_by_skill = agent.dig("stats", "damage_by_skill") || {}
      skill_ids.concat(damage_by_skill.keys.map(&:to_i))
      
      # Get skills from skills_used (ALL skills cast, including heals/prots)
      skills_used = agent.dig("stats", "skills_used") || {}
      skill_ids.concat(skills_used.keys.map(&:to_i))
      
      # Get skills from skill_ids_used as backup
      skill_ids_used = agent.dig("stats", "skill_ids_used") || []
      skill_ids.concat(skill_ids_used)
    end
    
    # Load all skills at once and return as hash
    Skill.where(skill_id: skill_ids.uniq).index_by(&:skill_id)
  end

  def match_params
    params.require(:match).permit(:json_file).merge(imported_by: current_player, imported_at: Time.zone.now)
  end

  def set_match
    @match = Match.find(params[:id])
  end
end
