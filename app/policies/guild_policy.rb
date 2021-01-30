class GuildPolicy < ApplicationPolicy
  attr_reader :user, :guild

  def initialize(user, guild)
    @user = user
    @guild = guild
  end

  def index?
    true
  end

  def show?
    true
  end

  def new?
    user
  end

  def create?
    user
  end
end
