class StreamersController < ApplicationController
  def index
    @streamers = Player.streamers.order(updated_at: :desc, created_at: :desc)
  end
end
