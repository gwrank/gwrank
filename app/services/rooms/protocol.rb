require "base64"

module Rooms
  class Protocol
    MAX_PAYLOAD_BYTES = 16 * 1024

    CLOSE_CODES = {
      normal: 1000,
      protocol_error: 1008,
      too_large: 1009,
      temporary_failure: 1013,
      creator_secret_invalid: 4401,
      room_not_found: 4404,
      room_full: 4409,
      rate_limited: 4429
    }.freeze

    class InvalidPayload < StandardError; end

    class << self
      def decode_payload(data)
        unless data.is_a?(Hash) && data.key?("payload") && data["payload"].is_a?(String)
          raise InvalidPayload
        end

        payload = data["payload"]
        decoded = Base64.strict_decode64(payload)
        raise InvalidPayload if decoded.bytesize > MAX_PAYLOAD_BYTES

        { payload: payload, bytesize: decoded.bytesize }
      rescue ArgumentError
        raise InvalidPayload
      end

      def ready(connection_id:, participants:, state: nil, expires_at:)
        {
          "type" => "room.ready",
          "connectionId" => connection_id,
          "participants" => participants,
          "state" => wire_state(state),
          "expiresAt" => wire_timestamp(expires_at)
        }
      end

      def joined(connection_id)
        { "type" => "room.joined", "connectionId" => connection_id }
      end

      def left(connection_id)
        { "type" => "room.left", "connectionId" => connection_id }
      end

      def state_updated(sender_id:, version:, payload:)
        {
          "type" => "state.updated",
          "senderId" => sender_id,
          "version" => version,
          "payload" => payload
        }
      end

      def expired(reason)
        { "type" => "room.expired", "reason" => reason }
      end

      private

      def wire_state(state)
        return if state.nil?

        {
          "version" => state.fetch(:version) { state.fetch("version") },
          "payload" => state.fetch(:payload) { state.fetch("payload") }
        }
      end

      def wire_timestamp(value)
        value.respond_to?(:iso8601) ? value.iso8601 : value
      end
    end
  end
end
