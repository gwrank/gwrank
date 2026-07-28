require 'test_helper'

module DiscordBot
  class ScrimPanelManagerTest < ActiveSupport::TestCase
    setup do
      @manager = ScrimPanelManager.instance
      @manager.instance_variable_set(:@active_panels, {})
    end

    test 'add_panel tracks panel correctly' do
      @manager.add_panel('server1', 'channel1', 'message1')
      
      assert_equal 1, @manager.instance_variable_get(:@active_panels).size
      assert @manager.instance_variable_get(:@active_panels)['server1']['channel1'].include?('message1')
    end

    test 'add_panel handles multiple panels in same channel' do
      @manager.add_panel('server1', 'channel1', 'message1')
      @manager.add_panel('server1', 'channel1', 'message2')
      
      assert_equal 2, @manager.instance_variable_get(:@active_panels)['server1']['channel1'].size
    end

    test 'add_panel handles multiple servers and channels' do
      @manager.add_panel('server1', 'channel1', 'message1')
      @manager.add_panel('server2', 'channel1', 'message1')
      @manager.add_panel('server1', 'channel2', 'message1')
      
      assert_equal 2, @manager.instance_variable_get(:@active_panels).size
      assert_equal 2, @manager.instance_variable_get(:@active_panels)['server1'].size
    end

    test 'remove_panel removes panel correctly' do
      @manager.add_panel('server1', 'channel1', 'message1')
      @manager.remove_panel('server1', 'channel1', 'message1')
      
      assert_nil @manager.instance_variable_get(:@active_panels)['server1']
    end

    test 'remove_panel cleans up empty channels' do
      @manager.add_panel('server1', 'channel1', 'message1')
      @manager.add_panel('server1', 'channel2', 'message1')
      @manager.remove_panel('server1', 'channel1', 'message1')
      
      refute @manager.instance_variable_get(:@active_panels)['server1'].key?('channel1')
      assert @manager.instance_variable_get(:@active_panels)['server1'].key?('channel2')
    end

    test 'remove_panel cleans up empty servers' do
      @manager.add_panel('server1', 'channel1', 'message1')
      @manager.remove_panel('server1', 'channel1', 'message1')
      
      refute @manager.instance_variable_get(:@active_panels).key?('server1')
    end

    test 'panel_content returns correct format with no registrations' do
      Registration.current_registrations.delete_all
      
      content = @manager.panel_content
      assert_includes content, '### Scrim Registration Panel'
      assert_includes content, 'No players currently registered'
    end

    test 'panel_content returns correct format with registrations' do
      player = create_player(uid: 'test_uid_123')
      Registration.current_registrations.delete_all
      player.registrations.create(registered_at: DateTime.now)
      
      content = @manager.panel_content
      assert_includes content, '### Scrim Registration Panel'
      assert_includes content, 'Current registered users:'
      assert_includes content, "<@#{player.uid}>"
    end

    test 'panel_components returns array with containers' do
      components = @manager.panel_components
      assert components.is_a?(Array)
      assert components.any?
    end
  end
end
