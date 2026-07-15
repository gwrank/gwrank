module DiscordBot
  class AtReminderCheck
    REMINDER_LEAD_TIME = 6.hours
    POLL_INTERVAL = 15.minutes

    def self.call(bot:)
      new(bot: bot).call
    end

    def initialize(bot:)
      @bot = bot
    end

    def call
      AutomatedTournamentSchedule.find_each { |schedule| check_schedule(schedule) }
    end

    private

    def check_schedule(schedule)
      now = Time.now.utc
      next_occ = schedule.next_occurrence(from: now)
      trigger_start = next_occ - REMINDER_LEAD_TIME
      trigger_end = trigger_start + POLL_INTERVAL

      return unless now >= trigger_start && now < trigger_end
      return if schedule.last_reminded_on == next_occ.to_date

      @bot.channel(schedule.channel_id).send_message(
        "Reminder: the next Automated Tournament (slot #{schedule.timezone.upcase}) starts at #{next_occ.strftime('%Y-%m-%d %H:%M UTC')} — get your team ready with */at join*!"
      )
      schedule.update!(last_reminded_on: next_occ.to_date)
    rescue StandardError => e
      Rails.logger.error("AtReminderCheck failed for schedule #{schedule.id} (server #{schedule.discord_server_id}): #{e.class}: #{e.message}")
    end
  end
end
