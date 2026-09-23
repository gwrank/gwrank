class RoomChannel < ApplicationCable::Channel
  PERMANENT_CLOSE_CODES = [4401, 4404, 4409].freeze
  STREAM_MESSAGE_TYPES = %w[room.joined room.left state.updated room.expired].freeze

  class_attribute :session_store, default: Rooms::SessionStore.new

  periodically :refresh_presence, every: 30.seconds

  private

  def subscribed
    @code = params.fetch("code", "").to_s.upcase
    @broadcasting = "rooms:#{@code}"
    @pending_messages = []
    @ready_transmitted = false
    @joined = false
    @left = false

    stream_from(@broadcasting, coder: ActiveSupport::JSON) do |message|
      handle_stream_message(message)
    end

    result = self.class.session_store.join!(
      code: @code,
      connection_id: connection_id,
      creator_secret: params["creatorSecret"]
    )
    @joined = true

    transmit_ready(result)
    broadcast(Rooms::Protocol.left(result[:replaced_connection_id])) if result[:replaced_connection_id]
    broadcast(Rooms::Protocol.joined(connection_id))
  rescue Rooms::SessionStore::Error => error
    stop_all_streams
    close_for_error(error)
    reject
  end

  def unsubscribed
    return if @left

    @left = true
    return unless @joined

    result = self.class.session_store.leave!(code: @code, connection_id: connection_id)
    broadcast(Rooms::Protocol.left(connection_id)) if result[:removed]
  end

  def refresh_presence
    return unless @joined && !@left

    result = self.class.session_store.touch!(code: @code, connection_id: connection_id)
    Array(result[:removed_ids]).each do |removed_id|
      broadcast(Rooms::Protocol.left(removed_id))
    end
    expire_room(result[:expired_reason]) if result[:expired_reason]
  rescue Rooms::SessionStore::Error => error
    close_for_error(error)
  end

  def transmit_ready(result)
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

  def handle_stream_message(message)
    message = ActiveSupport::JSON.decode(message) if message.is_a?(String)
    message = message.stringify_keys if message.respond_to?(:stringify_keys)
    return unless message.is_a?(Hash)

    type = message["type"]
    return unless STREAM_MESSAGE_TYPES.include?(type)
    return if type == "state.updated" && message["senderId"] == connection_id

    if @ready_transmitted
      transmit(message)
    else
      @pending_messages << message
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
