require "test_helper"

class RoomChannelTest < ActionCable::Channel::TestCase
  tests RoomChannel

  setup do
    @now = Time.utc(2026, 9, 23, 16)
    @cache = ActiveSupport::Cache::MemoryStore.new
    @store = Rooms::SessionStore.new(
      cache: @cache,
      clock: -> { @now },
      locker: ->(_key, &block) { block.call }
    )
    @previous_store = RoomChannel.session_store
    RoomChannel.session_store = @store
    @room = @store.create!
  end

  teardown do
    RoomChannel.session_store = @previous_store
  end

  test "confirms the first subscriber with the current room snapshot" do
    stub_connection_for("conn-1")

    subscribe code: @room[:code].downcase

    assert subscription.confirmed?
    assert_has_stream "rooms:#{@room[:code]}"
    assert_equal [ready_message("conn-1")], transmissions
  end

  test "broadcasts a join while the new subscriber receives its ready message" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    first_connection = connection

    stub_connection_for("conn-2")
    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.joined("conn-2")) do
      subscribe code: @room[:code].downcase
    end

    assert_equal [ready_message("conn-1")],
                 first_connection.transmissions.filter_map { |message| message["message"] }
    assert_equal [ready_message("conn-2", participants: %w[conn-1 conn-2])], transmissions
  end

  test "rejects an unknown room with a permanent close" do
    stub_connection_for("conn-1")

    subscribe code: "nope-123"

    assert subscription.rejected?
    assert_no_streams
    assert_equal [{ code: 4404, reason: "room_not_found", reconnect: false }], close_calls
  end

  test "rejects an invalid creator secret without exposing the secret" do
    stub_connection_for("conn-1")

    subscribe code: @room[:code], creatorSecret: "not-the-secret"

    assert subscription.rejected?
    assert_no_streams
    assert_equal [{ code: 4401, reason: "creator_secret_invalid", reconnect: false }], close_calls
    refute_includes close_calls.first[:reason], @room[:code]
    refute_includes close_calls.first[:reason], "not-the-secret"
  end

  test "rejects the ninth participant with a permanent close" do
    8.times do |index|
      @store.join!(code: @room[:code], connection_id: "conn-#{index}")
    end
    stub_connection_for("conn-9")

    subscribe code: @room[:code]

    assert subscription.rejected?
    assert_no_streams
    assert_equal [{ code: 4409, reason: "room_full", reconnect: false }], close_calls
  end

  test "buffers stream messages until ready and filters the sender's state update" do
    callback_holder = {}
    expires_at = @room[:expires_at]
    fake_store = Object.new
    fake_store.define_singleton_method(:join!) do |code:, connection_id:, creator_secret: nil|
      callback_holder.fetch(:block).call(Rooms::Protocol.joined("before-ready"))
      { participants: [connection_id], state: nil, expires_at: expires_at }
    end
    RoomChannel.session_store = fake_store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    channel.singleton_class.include(ActionCable::Channel::ChannelStub)

    channel.define_singleton_method(:stream_from) do |broadcasting, *args, **options, &block|
      callback_holder[:block] = block
    end
    channel.subscribe_to_channel

    assert_equal [ready_message("conn-1"), Rooms::Protocol.joined("before-ready")],
                 connection.transmissions.filter_map { |message| message["message"] }

    callback_holder.fetch(:block).call(Rooms::Protocol.state_updated(sender_id: "conn-1", version: 1, payload: "SELF"))
    callback_holder.fetch(:block).call(Rooms::Protocol.state_updated(sender_id: "conn-2", version: 2, payload: "OTHER"))
    callback_holder.fetch(:block).call(Rooms::Protocol.left("conn-2"))

    assert_equal [
      ready_message("conn-1"),
      Rooms::Protocol.joined("before-ready"),
      Rooms::Protocol.state_updated(sender_id: "conn-2", version: 2, payload: "OTHER"),
      Rooms::Protocol.left("conn-2")
    ], connection.transmissions.filter_map { |message| message["message"] }
  end

  test "renews presence and broadcasts removed members" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @store.join!(code: @room[:code], connection_id: "stale")
    @now += Rooms::SessionStore::PRESENCE_LEASE

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.left("stale")) do
      subscription.send(:refresh_presence)
    end
  end

  test "broadcasts expiry before closing the current subscriber" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @store.join!(
      code: @room[:code],
      connection_id: "creator",
      creator_secret: @room[:creator_secret]
    )
    @store.leave!(code: @room[:code], connection_id: "creator")
    @now += Rooms::SessionStore::CREATOR_GRACE

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.expired("creator_timeout")) do
      subscription.send(:refresh_presence)
    end

    assert_equal [{ code: 4404, reason: "creator_timeout", reconnect: false }], close_calls
  end

  test "leaves once and only broadcasts a removed member" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.left("conn-1")) do
      unsubscribe
    end
    assert_no_broadcasts("rooms:#{@room[:code]}") do
      subscription.unsubscribe_from_channel
    end
  end

  test "a stale replaced creator cannot start a new grace period" do
    stub_connection_for("creator-1")
    subscribe code: @room[:code], creatorSecret: @room[:creator_secret]
    old_subscription = subscription

    stub_connection_for("creator-2")
    subscribe code: @room[:code], creatorSecret: @room[:creator_secret]

    assert_no_broadcasts("rooms:#{@room[:code]}") do
      old_subscription.unsubscribe_from_channel
    end

    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_equal "creator-2", snapshot.fetch("creatorConnectionId")
    assert_nil snapshot.fetch("creatorGraceUntil")
  end

  test "registers the thirty-second presence renewal" do
    assert RoomChannel.periodic_timers.any? { |_callback, options| options.fetch(:every) == 30.seconds }
  end

  private

  def stub_connection_for(connection_id)
    stub_connection(connection_id: connection_id)
    connection.define_singleton_method(:close_with_code) do |**arguments|
      (@close_calls ||= []) << arguments
    end
  end

  def close_calls
    connection.instance_variable_get(:@close_calls) || []
  end

  def ready_message(connection_id, participants: [connection_id], state: nil)
    Rooms::Protocol.ready(
      connection_id: connection_id,
      participants: participants,
      state: state,
      expires_at: @room[:expires_at]
    )
  end
end
