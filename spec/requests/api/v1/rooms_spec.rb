# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Rooms API', swagger_doc: 'teambuilds.yaml', type: :request do
  path '/api/v1/rooms' do
    post 'Create a shared teambuild room' do
      produces 'application/json'
      security [{ bearerAuth: [] }]
      description <<~DESC.squish
        Creates an ephemeral shared room for the authenticated player. Clients subscribe to
        Action Cable using the returned websocketUrl and a command identifier shaped as
        {"channel":"RoomChannel","code":"ROOM-CODE","creatorSecret":"CREATOR-SECRET"}.
        The channel broadcasts room state and accepts packet, presence, and leave commands;
        the WebSocket stream itself is not modeled in this OpenAPI document.
      DESC

      let(:Authorization) { "Bearer #{@owner.api_token}" }

      response(201, 'Room created') do
        before do
          @owner = create_api_player
          @requested_at = Time.current
        end

        schema '$ref' => '#/components/schemas/RoomCreateResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['code']).to match(/\A[A-Z2-9]{4}-[A-Z2-9]{3}\z/)
          expect(data['creatorSecret']).to match(/\A[A-Za-z0-9_-]+\z/)
          expect(data['websocketUrl']).to match(%r{\Awss://.*?/cable\z})
          expect(Time.iso8601(data['expiresAt'])).to be_within(5.seconds).of(@requested_at + 2.hours)
          expect(data['limits']).to eq(
            'participants' => 8,
            'payloadBytes' => 16_384,
            'messagesPerSecond' => 10
          )
        end
      end

      response(503, 'No room capacity available') do
        before do
          @owner = create_api_player
          full_store = instance_double(Rooms::SessionStore)
          allow(full_store).to receive(:create!).and_raise(
            Rooms::SessionStore::Error.new(close_code: 503, reason: 'rooms_full')
          )
          allow(Rooms::SessionStore).to receive(:new).and_return(full_store)
        end

        schema '$ref' => '#/components/schemas/RoomError'

        run_test! do |response|
          expect(JSON.parse(response.body)).to eq(
            'errors' => [{ 'code' => 'rooms_full', 'message' => 'Aucune place de salon disponible' }]
          )
        end
      end

      response(401, 'Missing or invalid token') do
        let(:Authorization) { '' }

        run_test!
      end
    end
  end
end
