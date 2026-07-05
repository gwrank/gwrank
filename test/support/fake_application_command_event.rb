module DiscordBot
  module Test
    class FakeDiscordUser < Struct.new(:id, :username)
      alias_method :name, :username
    end

    class FakeChannel
      attr_reader :messages

      def initialize
        @messages = []
      end

      def send_message(content)
        @messages << content
      end
    end

    class FakeApplicationCommandEvent
      attr_reader :subcommand, :options, :user, :responses, :channel

      def initialize(subcommand:, user:, options: {})
        @subcommand = subcommand
        @user = user
        @options = options
        @responses = []
        @channel = FakeChannel.new
      end

      def respond(**kwargs, &block)
        @responses << kwargs
        block&.call(nil, nil)
      end
    end
  end
end
