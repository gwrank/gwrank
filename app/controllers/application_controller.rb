class ApplicationController < ActionController::Base
  include Pundit::Authorization

  private

  def pundit_user
    current_player
  end
end
