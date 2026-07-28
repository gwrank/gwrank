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
        
        interaction = Minitest::Mock.new
        event.expect(:interaction, interaction)
        event.expect(:respond, true) do |content: nil, has_components: nil, &block|
          assert_includes content, 'Scrim Registration Panel' if content
          assert has_components == true
          # Call the block with mock view
          view = Minitest::Mock.new
          view.expect(:add_component, true) do |component|
            assert component.is_a?(Hash) || component.is_a?(Array)
            true
          end
          block.call(nil, view) if block
          true
        end
        
        message = Minitest::Mock.new
        channel = Minitest::Mock.new
        interaction.expect(:message, message)
        message.expect(:channel, channel)
        message.expect(:id, 'message1')
        channel.expect(:id, 'channel1')
        
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
