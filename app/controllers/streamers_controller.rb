class StreamersController < ApplicationController
  def index
    @streamers = Player.streamers.order(username: :asc)
  end
end
