class SearchesController < ApplicationController
  def show
    @search_query = search_params[:q]
    @results = PgSearch.multisearch(@search_query)
    case @results.count
    when 1
      case @results.first.searchable_type
      when 'Guild'
        redirect_to guild_path(@results.first.searchable_id)
      when 'Character'
        character = Character.find(@results.first.searchable_id)
        if character.player.present?
          redirect_to player_path(character.player)
        elsif character.team_players.any?
          match = character.team_players.first.team.match
          redirect_to match_path(match)
        else
          redirect_to root_path
        end
      end
    else
      @players = Player.joins(:characters).where('characters.id IN (?)', @results.where(searchable_type: 'Character').pluck(:searchable_id))
      @guilds = Guild.where('id IN (?)', @results.where(searchable_type: 'Guild').pluck(:searchable_id))
    end
  end

  private

  def search_params
    params.permit(:q)
  end
end
