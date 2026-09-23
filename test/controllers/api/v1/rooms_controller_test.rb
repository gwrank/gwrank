require "test_helper"

module Api::V1
  class RoomsControllerTest < ActionDispatch::IntegrationTest
    test "creates a room for an API token" do
      player = create_player
      requested_at = Time.current

      post api_v1_rooms_path, headers: auth_headers(player)

      assert_response :created
      body = response.parsed_body
      assert_match(/\A[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{3}\z/, body.fetch("code"))
      assert_match(/\A[A-Za-z0-9_-]+\z/, body.fetch("creatorSecret"))
      assert_match(%r{\Awss://.*?/cable\z}, body.fetch("websocketUrl"))
      assert_in_delta requested_at + 2.hours, Time.iso8601(body.fetch("expiresAt")), 5.seconds
      assert_equal 8, body.dig("limits", "participants")
      assert_equal 16_384, body.dig("limits", "payloadBytes")
      assert_equal 10, body.dig("limits", "messagesPerSecond")
    end

    test "requires an API token" do
      post api_v1_rooms_path

      assert_response :unauthorized
    end

    test "rejects an invalid API token" do
      post api_v1_rooms_path, headers: { "Authorization" => "Bearer invalid-token" }

      assert_response :unauthorized
    end

    test "returns rooms_full when the store has reached capacity" do
      player = create_player
      full_store = Class.new do
        def create!
          raise Rooms::SessionStore::Error.new(close_code: 503, reason: "rooms_full")
        end
      end.new

      Rooms::SessionStore.stub(:new, full_store) do
        post api_v1_rooms_path, headers: auth_headers(player)
      end

      assert_response :service_unavailable
      assert_equal({
        "errors" => [{
          "code" => "rooms_full",
          "message" => "Aucune place de salon disponible"
        }]
      }, response.parsed_body)
      assert_not_includes response.parsed_body, "creatorSecret"
    end
  end
end
