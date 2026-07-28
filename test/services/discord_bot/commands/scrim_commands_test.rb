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
        
        # Mock interaction
        interaction = Minitest::Mock.new
        event.expect(:interaction, interaction)
        
        # Mock message - return nil to test fallback path
        interaction.expect(:message, nil)
        event.expect(:message, nil)
        
        # Mock respond to accept the block
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
        
        # Mock ScrimPanelManager - expect add_panel to be called with server_id only (fallback path)
        # Since we're returning nil for message, it won't call add_panel
        manager = Minitest::Mock.new
        manager.expect(:panel_content, 'Scrim Registration Panel')
        
        ScrimPanelManager.stub(:instance, manager) do
          commands = DiscordBot::Commands::ScrimCommands.new(bot)
          commands.send(:handle_panel, event)
        end
        
        # Verify all mocks
        assert_mock event
        assert_mock server
        assert_mock interaction
        assert_mock manager
      end
    end
  end
end
