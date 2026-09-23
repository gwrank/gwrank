module ApplicationCable
  module LoggingBoundary
    FILTERED = "[FILTERED]".freeze
    SENSITIVE_MARKERS = /creatorSecret|payload|identifier|data/i
    SEVERITIES = %i[debug info warn error fatal unknown].freeze

    class Logger
      def initialize(logger)
        @logger = logger
      end

      def add_tags(*tags)
        @logger.add_tags(*tags)
      end

      def tag(logger, &block)
        @logger.tag(logger, &block)
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

    def sanitize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), result|
          result[key] = sensitive_key?(key) ? FILTERED : sanitize(nested)
        end
      when Array
        value.map { |nested| sanitize(nested) }
      when String
        value.match?(SENSITIVE_MARKERS) ? FILTERED : value
      else
        value
      end
    end

    def sensitive_key?(key)
      key.to_s.match?(SENSITIVE_MARKERS)
    end
  end
end
