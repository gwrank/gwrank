class Administration::ApplicationController < ApplicationController
  before_action :authenticate_admin!
  layout 'administration'

  private

  def pundit_user
    current_admin
  end
end
