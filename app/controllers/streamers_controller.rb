class StreamersController < ApplicationController
  def index
    @streamers = Player.streamers
  end
end
