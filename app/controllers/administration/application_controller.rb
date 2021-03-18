class Administration::ApplicationController < ApplicationController
  before_action :authenticate_player!
  before_action :redirect_non_admins!

  layout 'administration'

  private

  def redirect_non_admins!
    redirect_to root_path unless current_player.is_admin?
  end
end
