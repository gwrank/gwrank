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
