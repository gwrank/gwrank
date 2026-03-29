class MatchesController < ApplicationController
  before_action :authenticate_player!, only: [:new, :create, :destroy]
  before_action :set_match, only: [:destroy]
  before_action :ensure_player_is_moderator_and_importer, only: [:destroy]

  def index
    @matches = Match.includes(teams: [:guild, { team_players: [:profession, :secondary_profession, { team_player_skills: :skill }] }]).order(played_at: :desc)
    
    # Get unique maps for the filter dropdown
    @unique_maps = Match.unique_maps
    
    # Apply filters
    @matches = @matches.where("played_at >= ?", params[:date_from].to_date.beginning_of_day) if params[:date_from].present?
    @matches = @matches.where("played_at <= ?", params[:date_to].to_date.end_of_day) if params[:date_to].present?
    
    # Tournament filter
    if params[:tournament_type].present?
      tournament_type = params[:tournament_type].downcase
      if tournament_type == 'mat'
        @matches = @matches.joins(:tournament).where(tournaments: { tournament_type: 'mat' })
      elsif tournament_type == 'at'
        @matches = @matches.joins(:tournament).where(tournaments: { tournament_type: 'at' })
        @matches = @matches.where(tournaments: { region: params[:tournament_region] }) if params[:tournament_region].present?
      end
    end
    
    # Map/Guild Hall filter
    if params[:map_id].present?
      @matches = @matches.where("json#>>'{map,map_id}' = ?", params[:map_id])
    end
    
    @pagy, @matches = pagy(@matches, limit: 4)
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
