require "test_helper"

module DiscordBot
  module Commands
    class ScrimCommandsTest < ActiveSupport::TestCase
       test 'handle_panel creates panel message' do
        # Mock the bot and event
        bot = Minitest::Mock.new
        event = Minitest::Mock.new
        server = Minitest::Mock.new
        channel = Minitest::Mock.new
        message = Minitest::Mock.new
        
        # Setup expectations
        event.expect(:server, server)
        server.expect(:id, 'server1')
        event.expect(:channel, channel)
        channel.expect(:id, 'channel1')
        message.expect(:id, 'message1')
        message.expect(:channel, channel)
        
        channel.expect(:send_message, message) do |**kwargs|
          content = kwargs[:content]
          components = kwargs[:components]
          assert_includes content, 'Scrim Registration Panel'
          assert components.is_a?(Array)
          message
        end
        
        # Mock ScrimPanelManager
        manager = Minitest::Mock.new
        manager.expect(:panel_content, 'Scrim Registration Panel')
        manager.expect(:panel_components, [])
        manager.expect(:add_panel, nil, ['server1', 'channel1', 'message1'])
        
        ScrimPanelManager.stub(:instance, manager) do
          commands = DiscordBot::Commands::ScrimCommands.new(bot)
          commands.send(:handle_panel, event)
        end
        
        # Verify all mocks
        assert_mock event
        assert_mock server
        assert_mock channel
        assert_mock message
        assert_mock manager
      end
    end
  end
end
