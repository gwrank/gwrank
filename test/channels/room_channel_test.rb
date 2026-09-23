require "test_helper"

class RoomChannelTest < ActionCable::Channel::TestCase
  tests RoomChannel

  class ControlledEventLoop
    class Timer
      def shutdown; end
    end

    def initialize
      @tasks = []
      @mutex = Mutex.new
      @condition = ConditionVariable.new
    end

    def post(task = nil, &block)
      @mutex.synchronize do
        @tasks << (task || block)
        @condition.broadcast
      end
    end

    def next_task(timeout: 0.5)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      @mutex.synchronize do
        while @tasks.empty?
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          return if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
        @tasks.shift
      end
    end

    def pending?
      @mutex.synchronize { @tasks.any? }
    end

    def timer(*)
      Timer.new
    end
  end

  class ControlledPubSub
    attr_accessor :after_success

    def initialize
      @subscriptions = Hash.new { |hash, channel| hash[channel] = [] }
      @mutex = Mutex.new
    end

    def subscribe(channel, callback, success_callback = nil)
      @mutex.synchronize do
        @subscriptions[channel] << callback
        success_callback&.call
      end
      after_success&.call
    end

    def unsubscribe(channel, callback)
      @mutex.synchronize do
        @subscriptions[channel].delete(callback)
        @subscriptions.delete(channel) if @subscriptions[channel].empty?
      end
    end

    def broadcast(channel, message)
      callbacks = @mutex.synchronize { @subscriptions.fetch(channel, []).dup }
      callbacks.each { |callback| callback.call(message) }
    end

    def active?(channel)
      @mutex.synchronize { @subscriptions.fetch(channel, []).any? }
    end
  end

  class FailingPubSub
    attr_reader :unsubscribe_calls

    def initialize(error)
      @error = error
      @unsubscribe_calls = []
    end

    def subscribe(*)
      raise @error
    end

    def unsubscribe(channel, callback)
      @unsubscribe_calls << [channel, callback]
    end
  end

  class QueuedWorkerPool
    def initialize
      @jobs = Queue.new
    end

    def async_invoke(target, method, message, connection:)
      @jobs << -> { target.public_send(method, message) }
    end

    def run_next
      @jobs.pop.call
    end

    def run_next_after(signal)
      signal << true
      run_next
    end

    def pending?
      @jobs.length.positive?
    end
  end

  ControlledServer = Struct.new(:event_loop, :pubsub)

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

  test "broadcasts stale members removed during admission" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @store.join!(code: @room[:code], connection_id: "stale")
    @now += Rooms::SessionStore::PRESENCE_LEASE

    messages = capture_broadcasts("rooms:#{@room[:code]}") do
      stub_connection_for("conn-2")
      subscribe code: @room[:code]
    end

    assert_includes messages, Rooms::Protocol.left("stale")
  end

  test "rejects an unknown room with a permanent close" do
    stub_connection_for("conn-1")

    assert_no_broadcasts("rooms:nope-123") do
      subscribe code: "nope-123"
    end

    assert subscription.rejected?
    assert_no_streams
    assert_equal [{ code: 4404, reason: "room_not_found", reconnect: false }], close_calls
  end

  test "rejects invalid room codes before creating a stream" do
    ["NOPE123", "A" * 100_000].each do |code|
      stub_connection_for("conn-1")

      subscribe code: code

      assert subscription.rejected?
      assert_no_streams
      assert_nil subscription.instance_variable_get(:@broadcasting)
      assert_equal [{ code: 4404, reason: "room_not_found", reconnect: false }], close_calls
    end
  end

  test "broadcasts expiry before rejecting a join to an expired room" do
    @now += Rooms::SessionStore::ROOM_TTL
    stub_connection_for("conn-1")

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.expired("max_lifetime")) do
      subscribe code: @room[:code]
    end

    assert subscription.rejected?
    assert_no_streams
    assert_equal [{ code: 4404, reason: "max_lifetime", reconnect: false }], close_calls
    assert_nil @cache.read("gwrank:rooms:v1:#{@room[:code]}")
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

  test "forwards a packet to the other subscribers with the incremented version" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    first_subscription = subscription
    first_connection = connection

    stub_connection_for("conn-2")
    subscribe code: @room[:code]

    encoded = Base64.strict_encode64("opaque zcx bytes")
    expected = Rooms::Protocol.state_updated(sender_id: "conn-1", version: 1, payload: encoded)
    assert_broadcast_on("rooms:#{@room[:code]}", expected) do
      first_subscription.perform_action("action" => "receive", "payload" => encoded)
    end
    subscription.send(:handle_stream_message, expected)

    assert_equal [ready_message("conn-1")], first_connection.transmissions.filter_map { |message| message["message"] }
    assert_equal [
      ready_message("conn-2", participants: %w[conn-1 conn-2]),
      expected
    ], transmissions
  end

  test "sanitizes room action metadata while receive gets the original data" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    encoded = Base64.strict_encode64("opaque action payload")
    action_data = { "action" => "receive", "payload" => encoded }
    expected = Rooms::Protocol.state_updated(sender_id: "conn-1", version: 1, payload: encoded)
    events = []
    subscriber = ->(*arguments) { events << arguments.last.dup }

    ActiveSupport::Notifications.subscribed(subscriber, "perform_action.action_cable") do
      messages = capture_broadcasts("rooms:#{@room[:code]}") do
        subscription.perform_action(action_data)
      end
      assert_equal [expected], messages
    end

    metadata = events.fetch(0)
    refute_includes metadata.inspect, encoded
    assert_equal :receive, metadata.fetch(:action)
    refute_includes RoomChannel.action_methods, "perform_action"
    assert_equal encoded, @cache.read("gwrank:rooms:v1:#{@room[:code]}").fetch("lastPayload")
  end

  test "keeps channel log output opaque while preserving transmitted data" do
    stub_connection_for("conn-1")
    output = StringIO.new
    raw_logger = ActiveSupport::Logger.new(output)
    connection.define_singleton_method(:logger) { raw_logger }
    creator_secret = "creator-secret-value"
    payload = Base64.strict_encode64("opaque payload")
    identifier = {
      "channel" => "RoomChannel",
      "code" => @room[:code],
      "creatorSecret" => creator_secret
    }.to_json
    channel = RoomChannel.new(connection, identifier, {})
    message = { "type" => "state.updated", "payload" => payload }

    channel.send(:transmit, message)

    assert_equal message, connection.transmissions.last.fetch("message")
    assert_equal identifier, connection.transmissions.last.fetch("identifier")
    refute_includes output.string, creator_secret
    refute_includes output.string, payload
  end

  test "redacts room ready participant identifiers from logs without changing the wire data" do
    stub_connection_for("conn-1")
    output = StringIO.new
    raw_logger = ActiveSupport::Logger.new(output)
    connection.define_singleton_method(:logger) { raw_logger }
    channel = RoomChannel.new(connection, { "channel" => "RoomChannel" }.to_json, {})
    participants = %w[opaque-connection-1 opaque-connection-2]
    message = Rooms::Protocol.ready(
      connection_id: participants.first,
      participants: participants,
      state: nil,
      expires_at: @room[:expires_at]
    )

    channel.send(:transmit, message)

    assert_equal message, connection.transmissions.last.fetch("message")
    participants.each { |connection_id| refute_includes output.string, connection_id }
    assert_includes output.string, "[FILTERED]"
  end

  test "sanitizes room transmit and broadcast metadata without changing the wire protocol" do
    stub_connection_for("conn-1")
    room_code = "KURZ-7T4"
    identifier = { "channel" => "RoomChannel", "code" => room_code }.to_json
    channel = RoomChannel.new(connection, identifier, {})
    channel.instance_variable_set(:@broadcasting, "rooms:#{room_code}")
    connection_id = "opaque-connection-id"
    payload = Base64.strict_encode64("opaque payload")
    message = Rooms::Protocol.state_updated(sender_id: connection_id, version: 1, payload: payload)
    events = []
    subscriber = ->(*arguments) { events << [arguments.first, arguments.last.dup] }

    ActiveSupport::Notifications.subscribed(subscriber, /\A(?:transmit|broadcast)\.action_cable\z/) do
      channel.send(:transmit, message, via: "streamed from rooms:#{room_code}")
      channel.send(:broadcast, message)
    end

    assert_equal message, connection.transmissions.last.fetch("message")
    assert_equal identifier, connection.transmissions.last.fetch("identifier")
    metadata = events.map(&:last).map(&:inspect).join
    refute_includes metadata, room_code
    refute_includes metadata, connection_id
    refute_includes metadata, payload
  end

  test "sanitizes room subscription confirmation metadata without changing its identifier" do
    stub_connection_for("conn-1")
    output = StringIO.new
    raw_logger = ActiveSupport::Logger.new(output)
    connection.define_singleton_method(:logger) { raw_logger }
    events = []
    subscriber = ->(*arguments) { events << [arguments.first, arguments.last.dup] }

    ActiveSupport::Notifications.subscribed(subscriber, "transmit_subscription_confirmation.action_cable") do
      subscribe code: @room[:code]
    end

    metadata = events.map(&:last).map(&:inspect).join
    refute_includes metadata, @room[:code]
    refute_includes output.string, @room[:code]
    assert subscription.confirmed?
  end

  test "sanitizes room subscription rejection metadata" do
    stub_connection_for("conn-1")
    output = StringIO.new
    raw_logger = ActiveSupport::Logger.new(output)
    connection.define_singleton_method(:logger) { raw_logger }
    creator_secret = "creator-secret-value"
    identifier = { "channel" => "RoomChannel", "code" => @room[:code], "creatorSecret" => creator_secret }.to_json
    channel = RoomChannel.new(connection, identifier, {})
    events = []
    subscriber = ->(*arguments) { events << [arguments.first, arguments.last.dup] }

    ActiveSupport::Notifications.subscribed(subscriber, "transmit_subscription_rejection.action_cable") do
      channel.send(:transmit_subscription_rejection)
    end

    metadata = events.map(&:last).map(&:inspect).join
    refute_includes metadata, @room[:code]
    refute_includes metadata, creator_secret
    refute_includes output.string, @room[:code]
    refute_includes output.string, creator_secret
    assert_equal identifier, connection.transmissions.last.fetch("identifier")
  end

  test "publishes opaque broadcasts without raw server broadcaster logs" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    output = StringIO.new
    logger = ActiveSupport::Logger.new(output)
    previous_logger = ActionCable.server.config.logger
    ActionCable.server.config.logger = logger
    payload = Base64.strict_encode64("opaque payload")
    message = Rooms::Protocol.state_updated(sender_id: "conn-2", version: 1, payload: payload)

    broadcasts = capture_broadcasts("rooms:#{@room[:code]}") do
      subscription.send(:broadcast, message)
    end

    assert_equal [message], broadcasts
    refute_includes output.string, payload
  ensure
    ActionCable.server.config.logger = previous_logger
  end

  test "broadcasts stale members removed while recording a packet" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @store.join!(code: @room[:code], connection_id: "stale")
    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    snapshot.fetch("members").fetch("stale")["lastSeen"] = (@now - Rooms::SessionStore::PRESENCE_LEASE).iso8601(6)
    @cache.write("gwrank:rooms:v1:#{@room[:code]}", snapshot, expires_in: Rooms::SessionStore::ROOM_TTL)

    messages = capture_broadcasts("rooms:#{@room[:code]}") do
      perform :receive, "payload" => Base64.strict_encode64("packet")
    end

    assert_includes messages, Rooms::Protocol.left("stale")
  end

  test "broadcasts every stale sender removal before closing the stale sender" do
    stub_connection_for("sender")
    subscribe code: @room[:code], creatorSecret: @room[:creator_secret]
    @store.join!(code: @room[:code], connection_id: "stale-peer")
    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    stale_at = (@now - Rooms::SessionStore::PRESENCE_LEASE).iso8601(6)
    snapshot.fetch("members").each_value { |member| member["lastSeen"] = stale_at }
    @cache.write("gwrank:rooms:v1:#{@room[:code]}", snapshot, expires_in: Rooms::SessionStore::ROOM_TTL)

    events = []
    original_broadcast = subscription.method(:broadcast)
    subscription.define_singleton_method(:broadcast) do |message|
      events << message
      original_broadcast.call(message)
    end
    original_close = connection.method(:close_with_code)
    connection.define_singleton_method(:close_with_code) do |**arguments|
      events << arguments
      original_close.call(**arguments)
    end

    perform :receive, "payload" => Base64.strict_encode64("packet")

    assert_equal [Rooms::Protocol.left("sender"), Rooms::Protocol.left("stale-peer"),
                  { code: 4404, reason: "room_not_found", reconnect: false }], events
    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_empty snapshot.fetch("members")
    assert_nil snapshot.fetch("creatorConnectionId")
    assert_equal (@now + Rooms::SessionStore::CREATOR_GRACE).iso8601(6),
                 snapshot.fetch("creatorGraceUntil")
  end

  test "closes malformed packets with a non-reconnectable protocol error" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]

    perform :receive, "payload" => "not base64"

    assert_equal [{ code: 1008, reason: "invalid_payload", reconnect: false }], close_calls
  end

  test "closes oversized packets without changing the stored state" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    encoded = Base64.strict_encode64("x" * (Rooms::Protocol::MAX_PAYLOAD_BYTES + 1))

    perform :receive, "payload" => encoded

    assert_equal [{ code: 1009, reason: "payload_too_large", reconnect: false }], close_calls
    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_equal 0, snapshot.fetch("stateVersion")
    assert_nil snapshot.fetch("lastPayload")
  end

  test "accepts a packet decoded to exactly the maximum payload size" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    encoded = Base64.strict_encode64("x" * Rooms::Protocol::MAX_PAYLOAD_BYTES)
    expected = Rooms::Protocol.state_updated(sender_id: "conn-1", version: 1, payload: encoded)

    assert_broadcast_on("rooms:#{@room[:code]}", expected) do
      perform :receive, "payload" => encoded
    end

    assert_empty close_calls
    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_equal 1, snapshot.fetch("stateVersion")
    assert_equal encoded, snapshot.fetch("lastPayload")
  end

  test "closes the eleventh packet in a rate window without changing the stored state" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    encoded = Base64.strict_encode64("packet")

    10.times { perform :receive, "payload" => encoded }
    perform :receive, "payload" => encoded

    assert_equal [{ code: 4429, reason: "rate_limited", reconnect: false }], close_calls
    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_equal 10, snapshot.fetch("stateVersion")
    assert_equal encoded, snapshot.fetch("lastPayload")
  end

  test "closes a packet from a missing member as a non-reconnectable room error" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @store.leave!(code: @room[:code], connection_id: "conn-1")

    perform :receive, "payload" => Base64.strict_encode64("packet")

    assert_equal [{ code: 4404, reason: "room_not_found", reconnect: false }], close_calls
  end

  test "broadcasts packet-triggered expiry before closing the sender" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @now += Rooms::SessionStore::ROOM_TTL

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.expired("max_lifetime")) do
      perform :receive, "payload" => Base64.strict_encode64("packet")
    end

    assert_equal [{ code: 4404, reason: "max_lifetime", reconnect: false }], close_calls
    assert_nil @cache.read("gwrank:rooms:v1:#{@room[:code]}")
  end

  test "registers the real stream before admission and orders worker callbacks" do
    event_loop = ControlledEventLoop.new
    pubsub = ControlledPubSub.new
    worker_pool = QueuedWorkerPool.new
    server = ControlledServer.new(event_loop, pubsub)
    state = {}
    expires_at = @room[:expires_at]
    fake_store = Object.new
    fake_store.define_singleton_method(:join!) do |code:, connection_id:, creator_secret: nil|
      state[:active_at_join] = pubsub.active?("rooms:#{code.to_s.upcase}")
      pubsub.broadcast(
        "rooms:#{code.to_s.upcase}",
        ActiveSupport::JSON.encode(Rooms::Protocol.joined("before-ready"))
      )
      worker_pool.run_next
      { participants: [connection_id], state: nil, expires_at: expires_at }
    end
    RoomChannel.session_store = fake_store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { worker_pool }

    connection.stub(:server, server) do
      thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      refute state.key?(:active_at_join)

      registration.call
      thread.join
      thread.value

      assert_equal true, state.fetch(:active_at_join)
      refute worker_pool.pending?

      pubsub.broadcast(
        "rooms:#{@room[:code]}",
        ActiveSupport::JSON.encode(Rooms::Protocol.state_updated(sender_id: "conn-1", version: 1, payload: "SELF"))
      )
      pubsub.broadcast(
        "rooms:#{@room[:code]}",
        ActiveSupport::JSON.encode(Rooms::Protocol.state_updated(sender_id: "conn-2", version: 2, payload: "OTHER"))
      )
      pubsub.broadcast(
        "rooms:#{@room[:code]}",
        ActiveSupport::JSON.encode(Rooms::Protocol.left("conn-2"))
      )
      3.times { worker_pool.run_next }
    end

    assert_equal [
      ready_message("conn-1"),
      Rooms::Protocol.joined("before-ready"),
      Rooms::Protocol.state_updated(sender_id: "conn-2", version: 2, payload: "OTHER"),
      Rooms::Protocol.left("conn-2")
    ], connection.transmissions.filter_map { |message| message["message"] }
  end

  test "serializes a worker callback with the ready flush" do
    event_loop = ControlledEventLoop.new
    pubsub = ControlledPubSub.new
    worker_pool = QueuedWorkerPool.new
    server = ControlledServer.new(event_loop, pubsub)
    expires_at = @room[:expires_at]
    fake_store = Object.new
    fake_store.define_singleton_method(:join!) do |code:, connection_id:, creator_secret: nil|
      broadcasting = "rooms:#{code.to_s.upcase}"
      pubsub.broadcast(broadcasting, ActiveSupport::JSON.encode(Rooms::Protocol.joined("before-ready")))
      worker_pool.run_next
      pubsub.broadcast(broadcasting, ActiveSupport::JSON.encode(Rooms::Protocol.joined("during-ready")))
      { participants: [connection_id], state: nil, expires_at: expires_at }
    end
    RoomChannel.session_store = fake_store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { worker_pool }
    flush_started = Queue.new
    release_flush = Queue.new
    original_transmit = connection.method(:transmit)
    connection.define_singleton_method(:transmit) do |cable_message|
      message = cable_message[:message] || cable_message["message"]
      if message.is_a?(Hash) && message["type"] == "room.joined" && message["connectionId"] == "before-ready"
        flush_started << true
        release_flush.pop
      end
      original_transmit.call(cable_message)
    end

    connection.stub(:server, server) do
      subscription_thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      registration.call
      flush_started.pop

      worker_started = Queue.new
      callback_thread = Thread.new { worker_pool.run_next_after(worker_started) }
      worker_started.pop
      release_flush << true
      callback_thread.join
      callback_thread.value
      subscription_thread.join
      subscription_thread.value
    end

    assert_equal [
      ready_message("conn-1"),
      Rooms::Protocol.joined("before-ready"),
      Rooms::Protocol.joined("during-ready")
    ], connection.transmissions.filter_map { |message| message["message"] }
  end

  test "does not leave a queued stream when admission rejects" do
    event_loop = ControlledEventLoop.new
    pubsub = ControlledPubSub.new
    server = ControlledServer.new(event_loop, pubsub)
    error = Rooms::SessionStore::Error.new(close_code: 4404, reason: "room_not_found")
    fake_store = Object.new
    fake_store.define_singleton_method(:join!) { |**| raise error }
    RoomChannel.session_store = fake_store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { QueuedWorkerPool.new }

    connection.stub(:server, server) do
      thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      registration.call
      thread.join
      thread.value
    end

    refute pubsub.active?("rooms:#{@room[:code]}")
    refute event_loop.pending?
  end

  test "cancels a pending stream before a disconnect can admit the member" do
    event_loop = ControlledEventLoop.new
    pubsub = ControlledPubSub.new
    server = ControlledServer.new(event_loop, pubsub)
    RoomChannel.session_store = @store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { QueuedWorkerPool.new }

    connection.stub(:server, server) do
      subscription_thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      channel.unsubscribe_from_channel
      registration.call
      subscription_thread.join
      subscription_thread.value
    end

    assert_equal ["probe"], @store.join!(code: @room[:code], connection_id: "probe")[:participants]
    refute pubsub.active?("rooms:#{@room[:code]}")
    refute event_loop.pending?
  end

  test "does not broadcast admission events after the channel leaves" do
    event_loop = ControlledEventLoop.new
    pubsub = ControlledPubSub.new
    server = ControlledServer.new(event_loop, pubsub)
    worker_pool = QueuedWorkerPool.new
    expires_at = @room[:expires_at]
    fake_store = Object.new
    fake_store.define_singleton_method(:join!) do |code:, connection_id:, creator_secret: nil|
      { participants: [connection_id], state: nil, expires_at: expires_at }
    end
    fake_store.define_singleton_method(:leave!) do |code:, connection_id:|
      { removed: true, expired_reason: nil }
    end
    RoomChannel.session_store = fake_store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { worker_pool }
    ready_started = Queue.new
    unsubscribe_started = Queue.new
    release_ready = Queue.new
    events = []
    original_transmit_ready = channel.method(:transmit_ready)
    channel.define_singleton_method(:transmit_ready) do |result|
      ready_started << true
      release_ready.pop
      original_transmit_ready.call(result)
    end
    original_broadcast = channel.method(:broadcast)
    channel.define_singleton_method(:broadcast) do |message|
      events << message
      original_broadcast.call(message)
    end
    original_unsubscribe = channel.method(:unsubscribe_from_channel)
    channel.define_singleton_method(:unsubscribe_from_channel) do
      instance_variable_set(:@unsubscribed, true)
      unsubscribe_started << true
      original_unsubscribe.call
    end

    connection.stub(:server, server) do
      subscription_thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      registration.call
      ready_started.pop

      unsubscribe_thread = Thread.new { channel.unsubscribe_from_channel }
      unsubscribe_started.pop
      release_ready << true
      subscription_thread.join
      unsubscribe_thread.join
    end

    assert_equal [Rooms::Protocol.left("conn-1")], events
  end

  test "skips admission when disconnect follows registration success" do
    event_loop = ControlledEventLoop.new
    pubsub = ControlledPubSub.new
    server = ControlledServer.new(event_loop, pubsub)
    RoomChannel.session_store = @store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { QueuedWorkerPool.new }
    pubsub.after_success = -> { channel.unsubscribe_from_channel }

    connection.stub(:server, server) do
      subscription_thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      registration.call
      subscription_thread.join
      subscription_thread.value
    end

    assert_equal ["probe"], @store.join!(code: @room[:code], connection_id: "probe")[:participants]
    refute pubsub.active?("rooms:#{@room[:code]}")
    refute event_loop.pending?
  end

  test "rejects a pubsub registration exception without blocking or admitting" do
    event_loop = ControlledEventLoop.new
    pubsub = FailingPubSub.new(StandardError.new("pubsub unavailable"))
    server = ControlledServer.new(event_loop, pubsub)
    state = { join_called: false }
    fake_store = Object.new
    fake_store.define_singleton_method(:join!) do |**|
      state[:join_called] = true
      flunk "join! must not run after stream registration fails"
    end
    RoomChannel.session_store = fake_store
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })
    connection.define_singleton_method(:worker_pool) { QueuedWorkerPool.new }

    connection.stub(:server, server) do
      subscription_thread = Thread.new { channel.subscribe_to_channel }
      registration = event_loop.next_task
      refute_nil registration
      registration.call rescue nil
      subscription_thread.join(0.2)
      refute_predicate subscription_thread, :alive?, "registration failure must release the waiting worker"
      subscription_thread.value
    ensure
      subscription_thread&.kill if subscription_thread&.alive?
      subscription_thread&.join
    end

    refute state.fetch(:join_called)
    assert_equal 1, pubsub.unsubscribe_calls.length
    assert_equal [{ code: 1013, reason: "stream_unavailable", reconnect: true }], close_calls
    refute event_loop.pending?
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
    subscription.send(:handle_stream_message, Rooms::Protocol.expired("creator_timeout"))

    assert_equal [{ code: 4404, reason: "creator_timeout", reconnect: false }], close_calls
  end

  test "broadcasts absolute expiry and closes every subscriber" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    first_subscription = subscription
    first_connection = connection

    stub_connection_for("conn-2")
    subscribe code: @room[:code]
    @now += Rooms::SessionStore::ROOM_TTL

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.expired("max_lifetime")) do
      subscription.send(:refresh_presence)
    end
    first_subscription.send(:handle_stream_message, Rooms::Protocol.expired("max_lifetime"))
    subscription.send(:handle_stream_message, Rooms::Protocol.expired("max_lifetime"))

    expected_close = { code: 4404, reason: "max_lifetime", reconnect: false }
    assert_equal [expected_close], first_connection.instance_variable_get(:@close_calls)
    assert_equal [expected_close], close_calls
    assert_nil @cache.read("gwrank:rooms:v1:#{@room[:code]}")
  end

  test "broadcasts absolute expiry after the snapshot is physically evicted" do
    stub_connection_for("conn-1")
    subscribe code: @room[:code]
    @cache.delete("gwrank:rooms:v1:#{@room[:code]}")
    @now += Rooms::SessionStore::ROOM_TTL

    assert_broadcast_on("rooms:#{@room[:code]}", Rooms::Protocol.expired("max_lifetime")) do
      subscription.send(:refresh_presence)
    end
    subscription.send(:handle_stream_message, Rooms::Protocol.expired("max_lifetime"))

    assert_equal [{ code: 4404, reason: "max_lifetime", reconnect: false }], close_calls
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

  test "targets the old creator with a permanent replacement close" do
    stub_connection_for("creator-1")
    subscribe code: @room[:code], creatorSecret: @room[:creator_secret]
    old_subscription = subscription
    old_connection = connection

    replacement_message = {
      "type" => RoomChannel::CREATOR_REPLACED_MESSAGE_TYPE,
      "connectionId" => "creator-1"
    }
    assert_broadcast_on("rooms:#{@room[:code]}", replacement_message) do
      stub_connection_for("creator-2")
      subscribe code: @room[:code], creatorSecret: @room[:creator_secret]
    end
    old_subscription.send(
      :handle_stream_message,
      replacement_message
    )
    old_subscription.send(:handle_stream_message, Rooms::Protocol.left("creator-2"))
    old_subscription.send(:handle_stream_message, Rooms::Protocol.joined("creator-2"))

    assert_equal [{ code: 4401, reason: "creator_replaced", reconnect: false }],
                 old_connection.instance_variable_get(:@close_calls)
    assert_equal [ready_message("creator-1")], old_connection.transmissions.filter_map { |message| message["message"] }
    assert_empty close_calls

    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_equal "creator-2", snapshot.fetch("creatorConnectionId")
    assert_nil snapshot.fetch("creatorGraceUntil")
  end

  test "a creator channel leave starts grace and a secret reconnect clears it" do
    stub_connection_for("creator-1")
    subscribe code: @room[:code], creatorSecret: @room[:creator_secret]
    creator_subscription = subscription

    stub_connection_for("observer")
    subscribe code: @room[:code]
    creator_subscription.unsubscribe_from_channel

    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_nil snapshot.fetch("creatorConnectionId")
    assert_equal (@now + Rooms::SessionStore::CREATOR_GRACE).iso8601(6), snapshot.fetch("creatorGraceUntil")

    @now += 1.minute
    stub_connection_for("creator-2")
    subscribe code: @room[:code], creatorSecret: @room[:creator_secret]

    snapshot = @cache.read("gwrank:rooms:v1:#{@room[:code]}")
    assert_equal "creator-2", snapshot.fetch("creatorConnectionId")
    assert_nil snapshot.fetch("creatorGraceUntil")
  end

  test "registers the thirty-second presence renewal" do
    assert RoomChannel.periodic_timers.any? { |_callback, options| options.fetch(:every) == 30.seconds }
  end

  test "can unsubscribe before subscription lifecycle state is initialized" do
    stub_connection_for("conn-1")
    channel = RoomChannel.new(connection, "test_stub", { "code" => @room[:code] })

    channel.unsubscribe_from_channel

    assert channel.unsubscribed?
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
