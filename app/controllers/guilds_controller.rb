class GuildsController < ApplicationController
  before_action :set_guild, only: [:show]

  def index
    @guilds = Guild.active.order(name: :asc)
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
