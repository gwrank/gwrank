class HomeController < ApplicationController
  def index
    @tournaments = Tournament.order(date: :desc).first(2)
    @matches = Match.order(played_at: :desc).first(1)
  end
end
