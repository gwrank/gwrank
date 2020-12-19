module Administration
  class PlayersController < ApplicationController
    def index
      @players = Player.order(created_at: :desc)
    end
  end
end
