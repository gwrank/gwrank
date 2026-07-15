require "test_helper"

module DiscordBot
  class AtReminderCheckTest < ActiveSupport::TestCase
    test "sends a reminder once the 6-hour-before window is entered" do
      schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
      next_occ = schedule.next_occurrence

      travel_to(next_occ - 6.hours) do
        bot = DiscordBot::Test::FakeBot.new
        AtReminderCheck.call(bot: bot)

        assert_equal 1, bot.channel("chan-1").messages.size
        assert_equal next_occ.to_date, schedule.reload.last_reminded_on
      end
    end

    test "does not send a second reminder for the same occurrence" do
      schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
      next_occ = schedule.next_occurrence

      travel_to(next_occ - 6.hours) do
        bot = DiscordBot::Test::FakeBot.new
        AtReminderCheck.call(bot: bot)
        AtReminderCheck.call(bot: bot)

        assert_equal 1, bot.channel("chan-1").messages.size
      end
    end

    test "does not send outside the trigger window" do
      schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
      next_occ = schedule.next_occurrence

      travel_to(next_occ - 7.hours) do
        bot = DiscordBot::Test::FakeBot.new
        AtReminderCheck.call(bot: bot)

        assert_equal 0, bot.channel("chan-1").messages.size
      end
    end

    test "a changed timezone (last_reminded_on reset to nil) is eligible again the same day" do
      schedule = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
      next_occ = schedule.next_occurrence
      schedule.update!(last_reminded_on: next_occ.to_date) # pretend already reminded

      travel_to(next_occ - 6.hours) do
        bot = DiscordBot::Test::FakeBot.new
        AtReminderCheck.call(bot: bot)
        assert_equal 0, bot.channel("chan-1").messages.size # already reminded, stays silent

        schedule.update!(last_reminded_on: nil) # /at schedule re-run with a changed timezone resets this
        AtReminderCheck.call(bot: bot)
        assert_equal 1, bot.channel("chan-1").messages.size
      end
    end

    test "one bad schedule's error does not stop reminders for another" do
      good = AutomatedTournamentSchedule.create!(discord_server_id: "server-1", timezone: "b", channel_id: "chan-1")
      bad = AutomatedTournamentSchedule.create!(discord_server_id: "server-2", timezone: "b", channel_id: "chan-2")
      next_occ = good.next_occurrence

      travel_to(next_occ - 6.hours) do
        bot = DiscordBot::Test::FakeBot.new
        def bot.channel(id)
          raise "boom" if id == "chan-2"

          super
        end

        assert_nothing_raised { AtReminderCheck.call(bot: bot) }
        assert_equal 1, bot.channel("chan-1").messages.size
        assert_nil bad.reload.last_reminded_on
      end
    end
  end
end
