class HomeController < ApplicationController
  def index
    @tournaments = Tournament.last(2)
  end
end
