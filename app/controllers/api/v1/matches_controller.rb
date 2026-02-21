class Api::V1::MatchesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_api_token

  def create
    @match = Match.import!(match_params)

    if @match
      render json: @match, only: [:id], status: :created, location: @match
    else
      render json: @match.errors, status: :unprocessable_entity
    end
  end

  private

  def match_params
    params.permit(:json_file).merge(imported_at: Time.zone.now, imported_by: @player)
  end

  def verify_api_token
    authenticate_or_request_with_http_token do |token, _options|
      @player = Player.find_by(api_token: token)
    end
  end
end
