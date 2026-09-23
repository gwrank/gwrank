require "test_helper"

module Api::V1
  class RoomsControllerTest < ActionDispatch::IntegrationTest
    test "creates a room for an API token" do
      player = create_player

      post api_v1_rooms_path, headers: auth_headers(player)

      assert_response :created
      body = response.parsed_body
      assert_match(/\A[A-Z2-9]{4}-[A-Z2-9]{3}\z/, body.fetch("code"))
      assert_match(/\A[A-Za-z0-9_-]+\z/, body.fetch("creatorSecret"))
      assert_match(%r{\Awss://.*?/cable\z}, body.fetch("websocketUrl"))
      assert_equal 8, body.dig("limits", "participants")
      assert_equal 16_384, body.dig("limits", "payloadBytes")
      assert_equal 10, body.dig("limits", "messagesPerSecond")
    end

    test "requires an API token" do
      post api_v1_rooms_path

      assert_response :unauthorized
    end
  end
end
