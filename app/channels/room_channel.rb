require_relative "application_cable/logging_boundary"

class RoomChannel < ApplicationCable::Channel
  PERMANENT_CLOSE_CODES = [1008, 1009, 4401, 4404, 4409, 4429].freeze
  STREAM_MESSAGE_TYPES = %w[room.joined room.left state.updated room.expired].freeze
  CREATOR_REPLACED_MESSAGE_TYPE = "room.creator.replaced"

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

  module ActionDispatchLogging
    def perform_action(data)
      action = extract_action(data)

      if processable_action?(action)
        metadata = ApplicationCable::LoggingBoundary.sanitize({
          channel_class: self.class.name,
          action: action,
          data: data
        })
        ActiveSupport::Notifications.instrument("perform_action.action_cable", metadata) do
          dispatch_action(action, data)
        end
      else
        logger.error "Unable to process #{action_signature(action, data)}"
      end
    end
  end
  prepend ActionDispatchLogging

  class_attribute :session_store, default: Rooms::SessionStore.new

  periodically :refresh_presence, every: 30.seconds
  before_unsubscribe :close_stream_delivery

  def initialize(connection, identifier, params = {})
    super
    @pending_messages = []
    @ready_transmitted = false
    @joined = false
    @left = false
    @stream_cancelled = false
    @stream_closed = false
    @pending_expiry_reason = nil
    @delivery_mutex = Mutex.new
    @lifecycle_mutex = Mutex.new
  end

  def logger
    @logging_boundary_logger ||= ApplicationCable::LoggingBoundary.wrap(connection.logger)
  end
  private :logger

  def receive(data)
    decoded = Rooms::Protocol.decode_payload(data)
    result = self.class.session_store.record_packet!(
      code: @code,
      connection_id: connection_id,
      payload: decoded.fetch(:payload)
    )
    Array(result[:removed_ids]).each do |removed_id|
      broadcast(Rooms::Protocol.left(removed_id))
    end
    broadcast(
      Rooms::Protocol.state_updated(
        sender_id: connection_id,
        version: result.fetch(:version),
        payload: decoded.fetch(:payload)
      )
    )
  rescue Rooms::Protocol::PayloadTooLarge
    close_connection(code: Rooms::Protocol::CLOSE_CODES.fetch(:too_large), reason: "payload_too_large")
  rescue Rooms::Protocol::InvalidPayload
    close_connection(code: Rooms::Protocol::CLOSE_CODES.fetch(:protocol_error), reason: "invalid_payload")
  rescue Rooms::SessionStore::ExpiredError => error
    expire_and_close(error)
  rescue Rooms::SessionStore::StaleMemberError => error
    Array(error.removed_ids).each do |removed_id|
      broadcast(Rooms::Protocol.left(removed_id))
    end
    close_for_error(error)
  rescue Rooms::SessionStore::Error => error
    close_for_error(error)
  end

  private

  def transmit(data, via: nil)
    logger.debug do
      status = "#{self.class.name} transmitting #{data.inspect.truncate(300)}"
      status += " (via #{via})" if via
      status
    end

    metadata = ApplicationCable::LoggingBoundary.sanitize({
      channel_class: self.class.name,
      data: data,
      via: via
    })
    ActiveSupport::Notifications.instrument("transmit.action_cable", metadata) do
      connection.transmit(identifier: @identifier, message: data)
    end
  end

  def transmit_subscription_confirmation
    return if subscription_confirmation_sent?

    logger.debug "#{self.class.name} is transmitting the subscription confirmation"
    metadata = ApplicationCable::LoggingBoundary.sanitize({
      channel_class: self.class.name,
      identifier: @identifier
    })
    ActiveSupport::Notifications.instrument("transmit_subscription_confirmation.action_cable", metadata) do
      connection.transmit(identifier: @identifier, type: ActionCable::INTERNAL[:message_types][:confirmation])
      @subscription_confirmation_sent = true
    end
  end

  def transmit_subscription_rejection
    logger.debug "#{self.class.name} is transmitting the subscription rejection"
    metadata = ApplicationCable::LoggingBoundary.sanitize({
      channel_class: self.class.name,
      identifier: @identifier
    })
    ActiveSupport::Notifications.instrument("transmit_subscription_rejection.action_cable", metadata) do
      connection.transmit(identifier: @identifier, type: ActionCable::INTERNAL[:message_types][:rejection])
    end
  end

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
    @code = Rooms::SessionStore.normalize_code(params.fetch("code", ""))
    unless @code
      close_connection(code: Rooms::Protocol::CLOSE_CODES.fetch(:room_not_found), reason: "room_not_found")
      reject
      return
    end

    @broadcasting = "rooms:#{@code}"

    stream_ready = stream_from(@broadcasting, coder: ActiveSupport::JSON) do |message|
      handle_stream_message(message)
    end
    unless stream_ready
      close_stream_delivery
      stop_all_streams
      reject
      return
    end

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
        if @left || unsubscribed?
          false
        else
          transmit_ready(result)
          if @left || unsubscribed?
            false
          else
            Array(result[:removed_ids]).each do |removed_id|
              broadcast(Rooms::Protocol.left(removed_id))
            end
            broadcast(creator_replaced_message(result[:replaced_connection_id])) if result[:replaced_connection_id]
            broadcast(Rooms::Protocol.left(result[:replaced_connection_id])) if result[:replaced_connection_id]
            broadcast(Rooms::Protocol.joined(connection_id))
            true
          end
        end
      end
    end
    unless admitted
      close_stream_delivery
      stop_all_streams
      reject
      return
    end

  rescue StreamRegistrationError, Rooms::SessionStore::Error => error
    if error.is_a?(Rooms::SessionStore::ExpiredError)
      expire_and_close(error)
    else
      close_stream_delivery
      stop_all_streams
      close_for_error(error)
    end
    reject
  end

  def unsubscribed
    removed = false
    expired_reason = nil
    @lifecycle_mutex.synchronize do
      return if @left

      @left = true
      if @joined
        result = self.class.session_store.leave!(code: @code, connection_id: connection_id)
        removed = result[:removed]
        expired_reason = result[:expired_reason]
      end
    end
    if expired_reason
      expire_room(expired_reason)
    else
      broadcast(Rooms::Protocol.left(connection_id)) if removed
    end
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
    expiry_reason = nil
    @delivery_mutex.synchronize do
      return if @stream_closed

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
      expiry_reason = @pending_expiry_reason
      @pending_expiry_reason = nil
      @stream_closed = true if expiry_reason
    end
    close_connection(code: 4404, reason: expiry_reason) if expiry_reason
  end

  def handle_stream_message(message)
    message = ActiveSupport::JSON.decode(message) if message.is_a?(String)
    message = message.stringify_keys if message.respond_to?(:stringify_keys)
    return unless message.is_a?(Hash)

    type = message["type"]

    if type == CREATOR_REPLACED_MESSAGE_TYPE
      if message["connectionId"] == connection_id
        should_close = @delivery_mutex.synchronize do
          next false if @stream_closed

          @stream_closed = true
          @pending_messages.clear
          true
        end
        close_connection(code: 4401, reason: "creator_replaced") if should_close
      end
      return
    end

    return unless STREAM_MESSAGE_TYPES.include?(type)
    return if type == "state.updated" && message["senderId"] == connection_id

    expiry_reason = nil
    @delivery_mutex.synchronize do
      return if @stream_closed

      if @ready_transmitted
        transmit(message)
        if type == "room.expired"
          expiry_reason = message.fetch("reason")
          @stream_closed = true
        end
      else
        @pending_messages << message
        @pending_expiry_reason = message.fetch("reason") if type == "room.expired"
      end
    end
    close_connection(code: 4404, reason: expiry_reason) if expiry_reason
  end

  def close_stream_delivery
    @delivery_mutex.synchronize do
      @stream_closed = true
      @pending_messages.clear
    end
  end

  def broadcast(message)
    ApplicationCable::LoggingBoundary.install!
    metadata = ApplicationCable::LoggingBoundary.sanitize({
      broadcasting: @broadcasting,
      message: message,
      coder: ActiveSupport::JSON
    })
    ActiveSupport::Notifications.instrument(
      "broadcast.action_cable",
      metadata
    ) do
      ActionCable.server.pubsub.broadcast(@broadcasting, ActiveSupport::JSON.encode(message))
    end
  end

  def expire_room(reason)
    broadcast(Rooms::Protocol.expired(reason))
  end

  def expire_and_close(error)
    close_stream_delivery
    stop_all_streams
    expire_room(error.reason)
    close_for_error(error)
  end

  def close_for_error(error)
    close_connection(code: error.close_code, reason: error.reason)
  end

  def close_connection(code:, reason:)
    connection.close_with_code(
      code: code,
      reason: reason,
      reconnect: !PERMANENT_CLOSE_CODES.include?(code)
    )
  end

  def creator_replaced_message(connection_id)
    {
      "type" => CREATOR_REPLACED_MESSAGE_TYPE,
      "connectionId" => connection_id
    }
  end
end
