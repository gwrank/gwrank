require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  def test_assigns_unique_connection_ids
    connect
    first_connection_id = connection.connection_id

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
end
