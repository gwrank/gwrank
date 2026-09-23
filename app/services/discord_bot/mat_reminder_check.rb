module DiscordBot
  class MatReminderCheck
    POLL_INTERVAL = 60 # seconds
    REMINDER_LEAD_TIME = 24.hours
    REGISTRATION_REMINDER_LEAD_TIME = 1.hour

    def self.call(bot:)
      new(bot: bot).call
    end

    def initialize(bot:)
      @bot = bot
    end

    def call
      AutomatedTournamentSchedule.where(is_monthly: true).find_each do |schedule|
        check_and_remind(schedule)
      rescue StandardError => e
        Rails.logger.error("MatReminderCheck failed for schedule #{schedule.id} (server #{schedule.discord_server_id}): #{e.class}: #{e.message}")
      end
    end

    private

    def check_and_remind(schedule)
      now = Time.now.utc
      next_occ = schedule.next_occurrence(from: now)

      check_24h_reminder(schedule, next_occ, now)
      check_registration_reminder(schedule, next_occ, now)
    end

    def check_24h_reminder(schedule, next_occ, now)
      trigger_start = next_occ - REMINDER_LEAD_TIME
      trigger_end = trigger_start + POLL_INTERVAL

      return unless now >= trigger_start && now < trigger_end
      return if schedule.last_reminded_on == next_occ.to_date

      send_reminder(schedule, next_occ)
      schedule.update!(last_reminded_on: next_occ.to_date)
    end

    def check_registration_reminder(schedule, next_occ, now)
      registration_start = next_occ - schedule.registration_opens_days_before.days
      trigger_start = registration_start - REGISTRATION_REMINDER_LEAD_TIME
      trigger_end = trigger_start + POLL_INTERVAL

      return unless now >= trigger_start && now < trigger_end
      return if schedule.last_registration_reminded_for == next_occ.to_date

      send_registration_opening_reminder(schedule, registration_start)
      schedule.update!(last_registration_reminded_for: next_occ.to_date)
    end

    def send_reminder(schedule, next_occ)
      channel = @bot.channel(schedule.channel_id)
      return unless channel

      message = "@here Monthly Automated Tournament reminder! The next monthly AT is in 24 hours (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')})."
      channel.send_message(message)
    end

    def send_registration_opening_reminder(schedule, registration_start)
      channel = @bot.channel(schedule.channel_id)
      return unless channel

      message = "@here Registration for the monthly Automated Tournament opens in 1 hour! (#{registration_start.strftime('%Y-%m-%d %H:%M UTC')})"
      channel.send_message(message)
    end
  end
end
