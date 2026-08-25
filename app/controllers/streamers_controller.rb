class StreamersController < ApplicationController
  layout "gw"

  def index
    @streamers = Player.streamers.order(updated_at: :desc, created_at: :desc)
  end
end
