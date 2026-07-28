require "test_helper"

module DiscordBot
  module Commands
    class ScrimCommandsTest < ActiveSupport::TestCase
      test 'handle_panel creates panel message' do
        # Mock the bot and event
        bot = Minitest::Mock.new
        event = Minitest::Mock.new
        server = Minitest::Mock.new
        interaction = Minitest::Mock.new
        message = Minitest::Mock.new
        channel = Minitest::Mock.new
        
        # Setup expectations
        event.expect(:server, server)
        server.expect(:id, 'server1')
        event.expect(:interaction, interaction)
        
        # Mock respond to accept the block and call it
        # We'll use a simple mock that doesn't verify the block contents
        event.expect(:respond, true) do |has_components: nil, &block|
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
          true
        end
        
        interaction.expect(:message, message)
        message.expect(:channel, channel)
        message.expect(:id, 'message1')
        channel.expect(:id, 'channel1')
        
        # Mock ScrimPanelManager
        manager = Minitest::Mock.new
        manager.expect(:panel_content, 'Scrim Registration Panel')
        manager.expect(:add_panel, nil, ['server1', 'channel1', 'message1'])
        
        ScrimPanelManager.stub(:instance, manager) do
          commands = DiscordBot::Commands::ScrimCommands.new(bot)
          commands.send(:handle_panel, event)
        end
        
        # Verify all mocks
        assert_mock event
        assert_mock server
        assert_mock interaction
        assert_mock message
        assert_mock channel
        assert_mock manager
      end
    end
  end
end
