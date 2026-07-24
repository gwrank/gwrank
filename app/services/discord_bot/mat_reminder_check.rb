module DiscordBot
  class MatReminderCheck
    POLL_INTERVAL = 60 # seconds
    
    def self.call(bot:)
      new(bot: bot).call
    end
    
    def initialize(bot:)
      @bot = bot
    end
    
    def call
      AutomatedTournamentSchedule.where(is_monthly: true).find_each do |schedule|
        check_and_remind(schedule)
      end
    end
    
    private
    
    def check_and_remind(schedule)
      now = Time.now.utc
      next_occ = schedule.next_occurrence(from: now)
      
      # Check if we need to send a reminder
      # Send reminder 24 hours before
      reminder_time = next_occ - 24.hours
      
      if now >= reminder_time && now <= next_occ
        send_reminder(schedule, next_occ)
      end
      
      # Also check for registration opening reminder
      registration_start = next_occ - schedule.registration_opens_days_before.days
      registration_reminder_time = registration_start - 1.hour
      
      if now >= registration_reminder_time && now <= registration_start
        send_registration_opening_reminder(schedule, registration_start)
      end
    end
    
    def send_reminder(schedule, next_occ)
      channel = @bot.channel(schedule.channel_id)
      return unless channel
      
      message = "@here Monthly Automated Tournament reminder! The next monthly AT is in 24 hours (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')})."
      channel.send_message(message)
    rescue StandardError => e
      Rails.logger.error("Failed to send MAT reminder: #{e.class}: #{e.message}")
    end
    
    def send_registration_opening_reminder(schedule, registration_start)
      channel = @bot.channel(schedule.channel_id)
      return unless channel
      
      message = "@here Registration for the monthly Automated Tournament opens in 1 hour! (#{registration_start.strftime('%Y-%m-%d %H:%M UTC')})"
      channel.send_message(message)
    rescue StandardError => e
      Rails.logger.error("Failed to send MAT registration reminder: #{e.class}: #{e.message}")
    end
  end
end
