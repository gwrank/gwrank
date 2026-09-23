module ApplicationCable
  module LoggingBoundary
    FILTERED = "[FILTERED]".freeze
    SENSITIVE_MARKERS = /creatorSecret|payload|identifier|data/i
    ROOM_CODE = /(?<![A-Z0-9])[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{3}(?![A-Z0-9])/i
    ROOM_BROADCASTING = /rooms:[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{3}/i
    ROOM_CONTEXT = /\bRoomChannel\b|\brooms:[^\s,)}]+|\broom\.(?:joined|left|expired|ready|creator\.replaced)\b/i
    ROOM_CONNECTION_FIELD = /(["']?(?:connectionId|senderId|creatorConnectionId)["']?\s*(?:=>|:)\s*["'])([^"']+)(["'])/
    ROOM_PARTICIPANTS = /(["']?participants["']?\s*(?:=>|:)\s*\[)[^\]]*(\])/i
    CONNECTION_LOG = /((?:Registered|Removing) connection \()([^)]+)(\))/
    BASE64_TOKEN = /(?<![A-Za-z0-9+\/])[A-Za-z0-9+\/]{16,}={0,2}(?![A-Za-z0-9+\/])/
    SEVERITIES = %i[debug info warn error fatal unknown].freeze

    module ServerBroadcaster
      def broadcast(message)
        server.logger.debug { "[ActionCable] Broadcasting to #{broadcasting}: #{message.inspect.truncate(300)}" }

        metadata = LoggingBoundary.sanitize({
          broadcasting: broadcasting,
          message: message,
          coder: coder
        })
        ActiveSupport::Notifications.instrument("broadcast.action_cable", metadata) do
          encoded = coder ? coder.encode(message) : message
          server.pubsub.broadcast broadcasting, encoded
        end
      end
    end

    class Logger
      def initialize(logger)
        @logger = logger
      end

      def add_tags(*tags)
        @logger.add_tags(*tags.map { |tag| LoggingBoundary.sanitize(tag) })
      end

      def tag(logger, &block)
        @logger.tag(LoggingBoundary.sanitize(logger), &block)
      end

      SEVERITIES.each do |severity|
        define_method(severity) do |message = nil, &block|
          sanitized_block = block && -> { LoggingBoundary.sanitize(block.call) }
          @logger.public_send(severity, LoggingBoundary.sanitize(message), &sanitized_block)
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @logger.respond_to?(method_name, include_private) || super
      end

      private

      def method_missing(method_name, ...)
        @logger.public_send(method_name, ...)
      end
    end

    module_function

    def wrap(logger)
      return logger if logger.is_a?(Logger)

      Logger.new(logger)
    end

    def install!
      return unless defined?(ActionCable) && ActionCable.respond_to?(:server)

      logger = ActionCable.server.config.logger
      ActionCable.server.config.logger = wrap(logger) if logger
      install_server_broadcaster!
    end

    def install_server_broadcaster!
      return unless defined?(ActionCable::Server::Broadcasting::Broadcaster)

      broadcaster = ActionCable::Server::Broadcasting::Broadcaster
      broadcaster.prepend(ServerBroadcaster) unless broadcaster.ancestors.include?(ServerBroadcaster)
    end

    def sanitize(value, room: false)
      case value
      when Hash
        room ||= room_hash?(value)
        value.each_with_object({}) do |(key, nested), result|
          result[key] = sensitive_key?(key) || (room && room_sensitive_key?(key)) ? FILTERED : sanitize(nested, room: room)
        end
      when Array
        value.map { |nested| sanitize(nested, room: room) }
      when String
        return FILTERED if value.match?(SENSITIVE_MARKERS)

        sanitized = value.gsub(CONNECTION_LOG) { "#{Regexp.last_match(1)}#{FILTERED}#{Regexp.last_match(3)}" }
        room_context?(sanitized) ? sanitize_room_string(sanitized) : sanitized
      else
        value
      end
    end

    def sensitive_key?(key)
      key.to_s.match?(SENSITIVE_MARKERS)
    end

    def room_sensitive_key?(key)
      key.to_s.match?(/\A(?:code|connectionId|senderId|creatorConnectionId)\z/)
    end

    def room_hash?(value)
      channel = value["channel"] || value[:channel]
      channel_class = value["channel_class"] || value[:channel_class]
      type = value["type"] || value[:type]
      broadcasting = value["broadcasting"] || value[:broadcasting]

      channel.to_s == "RoomChannel" || channel_class.to_s == "RoomChannel" ||
        type.to_s.start_with?("room.") || broadcasting.to_s.match?(/\Arooms:/i)
    end

    def room_context?(value)
      value.match?(ROOM_CONTEXT)
    end

    def sanitize_room_string(value)
      sanitized = value.gsub(ROOM_BROADCASTING, "rooms:#{FILTERED}")
      sanitized = sanitized.gsub(ROOM_CODE, FILTERED)
      sanitized = sanitized.gsub(ROOM_CONNECTION_FIELD) { "#{Regexp.last_match(1)}#{FILTERED}#{Regexp.last_match(3)}" }
      sanitized = sanitized.gsub(ROOM_PARTICIPANTS) { "#{Regexp.last_match(1)}#{FILTERED}#{Regexp.last_match(2)}" }
      sanitized.gsub(BASE64_TOKEN, FILTERED)
    end
  end
end
