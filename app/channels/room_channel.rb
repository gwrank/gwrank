class RoomChannel < ApplicationCable::Channel
  PERMANENT_CLOSE_CODES = [4401, 4404, 4409].freeze
  STREAM_MESSAGE_TYPES = %w[room.joined room.left state.updated room.expired].freeze

  class StreamRegistrationError < StandardError
    attr_reader :original_error

    def initialize(original_error)
      @original_error = original_error
      super("stream_unavailable")
    end

    def close_code
      1013
    end

    def reason
      "stream_unavailable"
    end
  end

  class_attribute :session_store, default: Rooms::SessionStore.new

  periodically :refresh_presence, every: 30.seconds
  before_unsubscribe :close_stream_delivery

  private

  # Action Cable's default stream_from only posts the subscription and returns. Keep the
  # same worker-pool handler, but wait for pubsub's success callback before admission.
  def stream_from(broadcasting, callback = nil, coder: nil, &block)
    return false if unsubscribed?

    broadcasting = String(broadcasting)
    defer_subscription_confirmation!
    handler = worker_pool_stream_handler(broadcasting, callback || block, coder: coder)
    streams[broadcasting] = handler
    @lifecycle_mutex.synchronize do
      @stream_cancelled = false
    end

    registered = Queue.new
    signal_mutex = Mutex.new
    signalled = false
    signal_registration = lambda do |result|
      signal_mutex.synchronize do
        unless signalled
          signalled = true
          registered << result
        end
      end
    end

    begin
      connection.server.event_loop.post do
        begin
          pubsub.subscribe(broadcasting, handler, lambda do
            begin
              cancelled = @lifecycle_mutex.synchronize { @stream_cancelled }
              if cancelled
                signal_registration.call(false)
              else
                ensure_confirmation_sent
                signal_registration.call(true)
              end
            rescue Exception => error
              signal_registration.call(StreamRegistrationError.new(error))
            end
          end)
        rescue Exception => error
          signal_registration.call(StreamRegistrationError.new(error))
        end
      end
    rescue Exception => error
      signal_registration.call(StreamRegistrationError.new(error))
    end
    registration_result = registered.pop
    if registration_result == true
      true
    else
      cleanup_stream_registration(broadcasting, handler)
      return false if registration_result == false

      raise registration_result
    end
  end

  def cleanup_stream_registration(broadcasting, handler)
    @lifecycle_mutex.synchronize { @stream_cancelled = true }
    streams.delete(broadcasting)
    begin
      pubsub.unsubscribe(broadcasting, handler)
    rescue Exception
      nil
    end
  end

  def stop_all_streams
    @lifecycle_mutex&.synchronize { @stream_cancelled = true }
    super
  end

  def subscribed
    @code = params.fetch("code", "").to_s.upcase
    @broadcasting = "rooms:#{@code}"
    @pending_messages = []
    @ready_transmitted = false
    @joined = false
    @left = false
    @stream_closed = false
    @delivery_mutex = Mutex.new
    @lifecycle_mutex = Mutex.new

    stream_ready = stream_from(@broadcasting, coder: ActiveSupport::JSON) do |message|
      handle_stream_message(message)
    end
    unless stream_ready
      close_stream_delivery
      stop_all_streams
      reject
      return
    end

    result = nil
    admitted = @lifecycle_mutex.synchronize do
      if @left || @stream_cancelled || unsubscribed?
        false
      else
        result = self.class.session_store.join!(
          code: @code,
          connection_id: connection_id,
          creator_secret: params["creatorSecret"]
        )
        @joined = true
        true
      end
    end
    unless admitted
      close_stream_delivery
      stop_all_streams
      reject
      return
    end

    transmit_ready(result)
    broadcast(Rooms::Protocol.left(result[:replaced_connection_id])) if result[:replaced_connection_id]
    broadcast(Rooms::Protocol.joined(connection_id))
  rescue StreamRegistrationError, Rooms::SessionStore::Error => error
    close_stream_delivery
    stop_all_streams
    close_for_error(error)
    reject
  end

  def unsubscribed
    removed = false
    @lifecycle_mutex.synchronize do
      return if @left

      @left = true
      if @joined
        removed = self.class.session_store.leave!(code: @code, connection_id: connection_id)[:removed]
      end
    end
    broadcast(Rooms::Protocol.left(connection_id)) if removed
  end

  def refresh_presence
    active = @lifecycle_mutex.synchronize { @joined && !@left }
    return unless active

    result = self.class.session_store.touch!(code: @code, connection_id: connection_id)
    Array(result[:removed_ids]).each do |removed_id|
      broadcast(Rooms::Protocol.left(removed_id))
    end
    expire_room(result[:expired_reason]) if result[:expired_reason]
  rescue Rooms::SessionStore::Error => error
    close_for_error(error)
  end

  def transmit_ready(result)
    @delivery_mutex.synchronize do
      transmit(
        Rooms::Protocol.ready(
          connection_id: connection_id,
          participants: result.fetch(:participants),
          state: result[:state],
          expires_at: result.fetch(:expires_at)
        )
      )
      @ready_transmitted = true
      @pending_messages.each { |message| transmit(message) }
      @pending_messages.clear
    end
  end

  def handle_stream_message(message)
    message = ActiveSupport::JSON.decode(message) if message.is_a?(String)
    message = message.stringify_keys if message.respond_to?(:stringify_keys)
    return unless message.is_a?(Hash)

    type = message["type"]
    return unless STREAM_MESSAGE_TYPES.include?(type)
    return if type == "state.updated" && message["senderId"] == connection_id

    @delivery_mutex.synchronize do
      return if @stream_closed

      if @ready_transmitted
        transmit(message)
      else
        @pending_messages << message
      end
    end
  end

  def close_stream_delivery
    @delivery_mutex.synchronize do
      @stream_closed = true
      @pending_messages.clear
    end
  end

  def broadcast(message)
    ActionCable.server.broadcast(@broadcasting, message)
  end

  def expire_room(reason)
    broadcast(Rooms::Protocol.expired(reason))
    connection.close_with_code(code: 4404, reason: reason, reconnect: false)
  end

  def close_for_error(error)
    connection.close_with_code(
      code: error.close_code,
      reason: error.reason,
      reconnect: !PERMANENT_CLOSE_CODES.include?(error.close_code)
    )
  end
end
