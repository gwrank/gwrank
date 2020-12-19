class Administration::ApplicationController < ApplicationController
  before_action :authenticate_admin!
end
