require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def test_installs_the_boundary_for_server_action_cable_logs
    assert_instance_of ApplicationCable::LoggingBoundary::Logger, ActionCable.server.config.logger
  end

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
    room_code = "KURZ-7T4"
    connection_id = "opaque-connection-id"
    payload = Base64.strict_encode64("opaque payload")
    identifier = { channel: "RoomChannel", code: room_code }.to_json

    logger.info("Unsubscribing from channel: #{identifier}")
    logger.info("RoomChannel is streaming from rooms:#{room_code}")
    logger.error("Could not execute command from (#{identifier})")
    logger.error("RoomChannel packet error: #{payload}")
    logger.info("RoomChannel presence {\"type\"=>\"room.joined\", \"connectionId\"=>\"#{connection_id}\"}")
    logger.info("Registered connection (#{connection_id})")
    logger.info("Removing connection (#{connection_id})")
    subscriptions_connection = Struct.new(:logger) do
      def rescue_with_handler(_error)
        nil
      end
    end.new(logger)
    ActionCable::Connection::Subscriptions.new(subscriptions_connection).execute_command(
      "command" => "unsubscribe", "identifier" => identifier
    )

    refute_includes output.string, room_code
    refute_includes output.string, connection_id
    refute_includes output.string, payload
    assert_includes output.string, "[FILTERED]"
    logger.info("ChatChannel is streaming from public-channel")
    assert_includes output.string, "ChatChannel is streaming from public-channel"
  end

  def test_sanitizes_action_cable_broadcast_logs_without_changing_the_wire_message
    output = StringIO.new
    previous_logger = ActionCable.server.config.logger
    ActionCable.server.config.logger = ActiveSupport::Logger.new(output)
    room_code = "KURZ-7T4"
    connection_id = "opaque-connection-id"
    creator_secret = "opaque-creator-secret"
    payload = { "type" => "state.updated", "senderId" => connection_id,
                "version" => 1, "payload" => Base64.strict_encode64("opaque payload"),
                "creatorSecret" => creator_secret }
    pubsub = Minitest::Mock.new
    pubsub.expect(:broadcast, nil, ["rooms:#{room_code}", ActiveSupport::JSON.encode(payload)])
    events = []
    subscriber = ->(*arguments) { events << arguments.last.dup }

    ActiveSupport::Notifications.subscribed(subscriber, "broadcast.action_cable") do
      ActionCable.server.stub(:pubsub, pubsub) do
        ApplicationCable::LoggingBoundary.install!
        ActionCable.server.broadcast("rooms:#{room_code}", payload)
      end
    end

    pubsub.verify
    metadata = events.fetch(0)
    refute_includes metadata.inspect, room_code
    refute_includes metadata.inspect, connection_id
    refute_includes metadata.inspect, creator_secret
    refute_includes metadata.inspect, payload.fetch("payload")
    refute_includes output.string, room_code
    refute_includes output.string, connection_id
    refute_includes output.string, payload.fetch("payload")
  ensure
    ActionCable.server.config.logger = previous_logger
  end
end
