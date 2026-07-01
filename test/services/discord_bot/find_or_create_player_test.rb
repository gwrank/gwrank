require "test_helper"

module DiscordBot
  class FindOrCreatePlayerTest < ActiveSupport::TestCase
    FakeUser = Struct.new(:id, :name)
    FakeEvent = Struct.new(:user)

    test "creates a new player from a discord event on first use" do
      event = FakeEvent.new(FakeUser.new('123456', 'SomeDiscordName'))

      player = DiscordBot::FindOrCreatePlayer.call(event)

      assert player.persisted?
      assert_equal 'discord', player.provider
      assert_equal '123456', player.uid
      assert_equal 'SomeDiscordName', player.username
      assert_equal '123456@gwrank.com', player.email
    end

    test "returns the existing player on subsequent calls for the same discord uid" do
      event = FakeEvent.new(FakeUser.new('123456', 'SomeDiscordName'))
      first = DiscordBot::FindOrCreatePlayer.call(event)

      second = DiscordBot::FindOrCreatePlayer.call(event)

      assert_equal first.id, second.id
    end
  end
end
