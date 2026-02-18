# frozen_string_literal: true

namespace :discord_bot do
  task run: :environment do
    CommandBotJob.perform_now
  end
end
