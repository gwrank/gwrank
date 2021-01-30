class ApplicationController < ActionController::Base
  include Pundit

  private

  def pundit_user
    current_player
  end
end
