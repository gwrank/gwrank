class Api::V1::RoomsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_api_token

  def create
    room = Rooms::SessionStore.new.create!

    render json: {
      code: room.fetch(:code),
      creatorSecret: room.fetch(:creator_secret),
      websocketUrl: websocket_url,
      expiresAt: room.fetch(:expires_at).iso8601,
      limits: {
        participants: Rooms::SessionStore::MAX_PARTICIPANTS,
        payloadBytes: Rooms::Protocol::MAX_PAYLOAD_BYTES,
        messagesPerSecond: Rooms::SessionStore::MESSAGES_PER_SECOND
      }
    }, status: :created
  rescue Rooms::SessionStore::Error => error
    raise unless error.close_code == 503 && error.reason == "rooms_full"

    render json: {
      errors: [{ code: "rooms_full", message: "Aucune place de salon disponible" }]
    }, status: :service_unavailable
  end

  private

  def verify_api_token
    authenticate_or_request_with_http_token do |token, _options|
      @player = Player.find_by(api_token: token)
    end
  end

  def websocket_url
    request.base_url.sub(/\/\z/, "").sub(/\Ahttps?/, "wss") + "/cable"
  end
end
