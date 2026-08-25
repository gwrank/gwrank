class GuildsController < ApplicationController
  before_action :set_guild, only: [:show]

  def index
    @pagy, @guilds = pagy(
      Guild.includes(:players)
        .active
        .joins("LEFT JOIN players ON players.guild_id = guilds.id")
        .group("guilds.id")
        .order('AVG(players.elo_rating) DESC NULLS LAST, guilds.members_count DESC, guilds.gold_trims_count DESC, guilds.silver_trims_count DESC, guilds.bronze_trims_count DESC, guilds.name ASC')
    )
    authorize @guilds
  end

  def show
    authorize @guild
  end

  def new
    @guild = Guild.new
    authorize @guild
  end

  def create
    @guild = Guild.new(guild_params)
    authorize @guild

    if @guild.save
      current_player.update(guild: @guild)
      redirect_to guild_path(@guild)
    else
      render :new
    end
  end

  private

  def set_guild
    @guild = Guild.friendly.find(params[:id])
  end

  def guild_params
    params.require(:guild).permit(:name, :tag).merge(owner: current_player)
  end
end
