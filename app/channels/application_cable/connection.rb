require_relative "logging_boundary"

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :connection_id

    def connect
      LoggingBoundary.install!
      @logger = LoggingBoundary.wrap(@logger)
      self.connection_id = SecureRandom.uuid
    end

    def logger
      @logging_boundary_logger ||= LoggingBoundary.wrap(super)
    end

    def close_with_code(code:, reason:, reconnect:)
      transmit(
        type: ActionCable::INTERNAL[:message_types][:disconnect],
        reason: reason,
        reconnect: reconnect
      )
      websocket.close(code, reason)
    end
  end
end
