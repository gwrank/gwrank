module DiscordBot
  module Test
    class FakeDiscordUser < Struct.new(:id, :username)
      alias_method :name, :username
    end

    class FakeChannel
      attr_reader :messages, :id

      def initialize(id: nil)
        @id = id
        @messages = []
      end

      def send_message(content)
        @messages << content
      end
    end

    class FakeBot
      def initialize
        @channels = Hash.new { |hash, key| hash[key] = FakeChannel.new(id: key) }
      end

      def channel(id)
        @channels[id]
      end
    end

    class FakeApplicationCommandEvent
      attr_reader :subcommand, :options, :user, :responses, :channel

      def initialize(subcommand:, user:, options: {}, channel_id: nil)
        @subcommand = subcommand
        @user = user
        @options = options
        @responses = []
        @channel = FakeChannel.new(id: channel_id)
      end

      def respond(**kwargs, &block)
        @responses << kwargs
        block&.call(nil, nil)
      end
    end
  end
end
