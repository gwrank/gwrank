class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  private

  def pundit_user
    current_player
  end
end
