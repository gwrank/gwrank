# frozen_string_literal: true

namespace :guilds do
    task count_trims: :environment do
      Guild.all.each do |guild|
        gold_trims_count = guild.tournament_results.gold_trims.count
        silver_trims_count = guild.tournament_results.silver_trims.count
        bronze_trims_count = guild.tournament_results.bronze_trims.count
        guild.update(
            gold_trims_count: gold_trims_count,
            silver_trims_count: silver_trims_count,
            bronze_trims_count: bronze_trims_count
        )
      end
    end
  end
  