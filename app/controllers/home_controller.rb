class HomeController < ApplicationController
  def index
    @queue_count = Player.in_queue.count
    @recent_scrims = Scrim.decided.order(created_at: :desc).limit(5)
    @scrims_count = Scrim.decided.count
  end
end
