require "test_helper"

module DiscordBot
  class MatReminderCheckTest < ActiveSupport::TestCase
    def build_monthly_schedule
      AutomatedTournamentSchedule.create!(
        discord_server_id: "server-1",
        is_monthly: true,
        recurrence_pattern: "every_3rd_saturday",
        channel_id: "mat-chan",
        registration_opens_days_before: 28
      )
    end

    test "sends the 24h reminder once when entering the trigger window" do
      schedule = build_monthly_schedule
      next_occ = schedule.next_occurrence(from: Time.utc(2026, 9, 1))
      assert_equal Time.utc(2026, 9, 19, 0, 0), next_occ

      travel_to(next_occ - 24.hours) do
        bot = DiscordBot::Test::FakeBot.new
        MatReminderCheck.call(bot: bot)

        assert_equal 1, bot.channel("mat-chan").messages.size
      end
    end

    test "does not spam when polled repeatedly inside the 24h window" do
      schedule = build_monthly_schedule
      next_occ = schedule.next_occurrence(from: Time.utc(2026, 9, 1))

      travel_to(next_occ - 24.hours) do
        bot = DiscordBot::Test::FakeBot.new
        7.times { MatReminderCheck.call(bot: bot) }

        assert_equal 1, bot.channel("mat-chan").messages.size,
          "expected a single reminder, got #{bot.channel('mat-chan').messages.size} (spam)"
      end

      # Later inside the old 24h-wide window: stays silent (already reminded)
      travel_to(next_occ - 23.hours) do
        bot = DiscordBot::Test::FakeBot.new
        7.times { MatReminderCheck.call(bot: bot) }

        assert_equal 0, bot.channel("mat-chan").messages.size
      end
    end

    test "does not send outside the trigger window" do
      schedule = build_monthly_schedule
      next_occ = schedule.next_occurrence(from: Time.utc(2026, 9, 1))

      travel_to(next_occ - 25.hours) do
        bot = DiscordBot::Test::FakeBot.new
        MatReminderCheck.call(bot: bot)

        assert_equal 0, bot.channel("mat-chan").messages.size
      end
    end

    test "sends the registration reminder once and does not spam" do
      schedule = build_monthly_schedule
      next_occ = schedule.next_occurrence(from: Time.utc(2026, 9, 1))
      registration_start = next_occ - 28.days

      travel_to(registration_start - 1.hour) do
        bot = DiscordBot::Test::FakeBot.new
        7.times { MatReminderCheck.call(bot: bot) }

        assert_equal 1, bot.channel("mat-chan").messages.size,
          "registration reminder spammed"
      end
    end

    test "one bad schedule does not stop reminders for another" do
      good = AutomatedTournamentSchedule.create!(
        discord_server_id: "server-1", is_monthly: true,
        recurrence_pattern: "every_3rd_saturday", channel_id: "chan-1"
      )
      AutomatedTournamentSchedule.create!(
        discord_server_id: "server-2", is_monthly: true,
        recurrence_pattern: "every_3rd_saturday", channel_id: "chan-2"
      )
      next_occ = good.next_occurrence(from: Time.utc(2026, 9, 1))

      travel_to(next_occ - 24.hours) do
        bot = DiscordBot::Test::FakeBot.new
        def bot.channel(id)
          raise "boom" if id == "chan-2"

          super
        end

        assert_nothing_raised { MatReminderCheck.call(bot: bot) }
        assert_equal 1, bot.channel("chan-1").messages.size
      end
    end
  end
end
