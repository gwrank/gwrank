require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def test_assigns_unique_connection_ids
    connect
    first_connection_id = connection.connection_id
    assert_instance_of ApplicationCable::LoggingBoundary::Logger, connection.logger

    connect
    second_connection_id = connection.connection_id

    refute_equal first_connection_id, second_connection_id
  end

  def test_close_with_code_transmits_disconnect_and_closes_websocket
    connect
    websocket = Minitest::Mock.new
    websocket.expect(:close, nil, [4404, "room expired"])
    transmitted_message = nil

    connection.stub(:transmit, ->(message) { transmitted_message = message }) do
      connection.stub(:websocket, websocket) do
        connection.close_with_code(code: 4404, reason: "room expired", reconnect: false)
      end
    end

    websocket.verify
    assert_equal(
      {
        type: ActionCable::INTERNAL[:message_types][:disconnect],
        reason: "room expired",
        reconnect: false
      },
      transmitted_message
    )
  end

  def test_sanitizes_sensitive_values_in_action_cable_log_messages
    output = StringIO.new
    raw_logger = ActiveSupport::Logger.new(output)
    cable_connection = ApplicationCable::Connection.allocate
    cable_connection.instance_variable_set(:@logger, raw_logger)
    logger = cable_connection.logger
    creator_secret = "creator-secret-value"
    payload = Base64.strict_encode64("opaque payload")
    identifier = { channel: "RoomChannel", code: "ABCD-234", creatorSecret: creator_secret }.to_json

    logger.info("Unsubscribing from channel: #{identifier}")
    logger.error("Could not execute command from (#{identifier})")
    logger.debug { "RoomChannel transmitting {\"payload\"=>\"#{payload}\"}" }
    subscriptions_connection = Struct.new(:logger) do
      def rescue_with_handler(_error)
        nil
      end
    end.new(logger)
    ActionCable::Connection::Subscriptions.new(subscriptions_connection).execute_command(
      "command" => "unsubscribe", "identifier" => identifier
    )

    refute_includes output.string, creator_secret
    refute_includes output.string, payload
    assert_includes output.string, "[FILTERED]"
  end
end
