require "test_helper"

module DiscordBot
  module Commands
    class ScrimCommandsTest < ActiveSupport::TestCase
      test 'handle_panel creates panel message' do
        # Mock the bot and event with minimal expectations
        bot = Minitest::Mock.new
        event = Minitest::Mock.new
        server = Minitest::Mock.new
        
        # Setup basic expectations
        event.expect(:server, server)
        server.expect(:id, 'server1')
        
        # Mock respond to accept the block and return a message
        message = Minitest::Mock.new
        channel = Minitest::Mock.new
        channel.expect(:id, 'channel1')
        message.expect(:channel, channel)
        message.expect(:id, 'message1')
        
        event.expect(:respond, message) do |has_components: nil, &block|
          assert has_components == true
          
          # Call the block with a simple mock view if provided
          if block
            view = Object.new
            def view.container(&block)
              @container = Object.new
              def @container.text_display(content: nil)
                true
              end
              def @container.row(&block)
                @row = Object.new
                def @row.button(label: nil, style: nil, custom_id: nil)
                  true
                end
                block.call(@row)
              end
              block.call(@container)
            end
            block.call(nil, view)
          end
          message
        end
        
        # Mock ScrimPanelManager - expect add_panel to be called
        manager = Minitest::Mock.new
        manager.expect(:panel_content, 'Scrim Registration Panel')
        manager.expect(:add_panel, true) do |server_id, channel_id, message_id|
          assert_equal 'server1', server_id
          assert_equal 'channel1', channel_id
          assert_equal 'message1', message_id
          true
        end
        
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
