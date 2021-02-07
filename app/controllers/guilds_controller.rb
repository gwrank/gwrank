class GuildsController < ApplicationController
  before_action :set_guild, only: [:show, :edit]

  def index
    authorize Guild
    @guilds = Guild.all.order(name: :asc)
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
    @guild.owner = current_player
    authorize @guild
    if @guild.save
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
    params.require(:guild).permit(:name, :tag)
  end
end
