require "test_helper"
require "base64"

module Rooms
  class ProtocolTest < ActiveSupport::TestCase
    test "decodes a valid opaque payload without inspecting its contents" do
      encoded = Base64.strict_encode64('{"version":19,"encrypted":true}')

      assert_equal({ payload: encoded, bytesize: 31 }, Protocol.decode_payload("payload" => encoded))
    end

    test "accepts opaque bytes that are not JSON" do
      encoded = Base64.strict_encode64("\xFF\x00".b)

      assert_equal({ payload: encoded, bytesize: 2 }, Protocol.decode_payload("payload" => encoded))
    end

    test "rejects invalid action shapes" do
      assert_raises(Protocol::InvalidPayload) { Protocol.decode_payload(nil) }
      assert_raises(Protocol::InvalidPayload) { Protocol.decode_payload({}) }
    end

    test "rejects a non-string payload" do
      assert_raises(Protocol::InvalidPayload) { Protocol.decode_payload("payload" => 123) }
    end

    test "rejects malformed base64 and oversize decoded payloads" do
      assert_raises(Protocol::InvalidPayload) { Protocol.decode_payload("payload" => "not base64!") }

      encoded = Base64.strict_encode64("x" * Protocol::MAX_PAYLOAD_BYTES.next)
      assert_raises(Protocol::InvalidPayload) { Protocol.decode_payload("payload" => encoded) }
    end

    test "builds the documented server envelopes" do
      assert_equal({ "type" => "room.joined", "connectionId" => "conn-1" },
                   Protocol.joined("conn-1"))
      assert_equal({ "type" => "room.left", "connectionId" => "conn-1" },
                   Protocol.left("conn-1"))
      assert_equal({ "type" => "state.updated", "senderId" => "conn-1", "version" => 3,
                     "payload" => "BASE64" },
                   Protocol.state_updated(sender_id: "conn-1", version: 3, payload: "BASE64"))
      assert_equal({ "type" => "room.expired", "reason" => "creator_timeout" },
                   Protocol.expired("creator_timeout"))
    end

    test "builds a ready envelope with a nullable state" do
      expires_at = Time.utc(2026, 9, 23, 18)

      assert_equal({
        "type" => "room.ready",
        "connectionId" => "conn-1",
        "participants" => ["conn-1"],
        "state" => nil,
        "expiresAt" => "2026-09-23T18:00:00Z"
      }, Protocol.ready(connection_id: "conn-1", participants: ["conn-1"], state: nil,
                         expires_at: expires_at))
    end

    test "builds a ready envelope with a string-keyed state" do
      assert_equal({
        "type" => "room.ready",
        "connectionId" => "conn-1",
        "participants" => ["conn-1", "conn-2"],
        "state" => { "version" => 3, "payload" => "BASE64" },
        "expiresAt" => "2026-09-23T18:00:00Z"
      }, Protocol.ready(connection_id: "conn-1", participants: ["conn-1", "conn-2"],
                         state: { version: 3, payload: "BASE64" },
                         expires_at: Time.utc(2026, 9, 23, 18)))
    end

    test "defines the documented close codes" do
      assert_equal({
        normal: 1000,
        protocol_error: 1008,
        too_large: 1009,
        temporary_failure: 1013,
        creator_secret_invalid: 4401,
        room_not_found: 4404,
        room_full: 4409,
        rate_limited: 4429
      }, Protocol::CLOSE_CODES)
      assert_predicate Protocol::CLOSE_CODES, :frozen?
    end
  end
end
