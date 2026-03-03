class StatisticsController < ApplicationController
  def index
    @best_dpm_players = Player.order(average_dpm: :desc).first(5)

    @most_picked_skills = TeamPlayerSkill.joins(:skill)
      .where.not('skills.name': 'No Skill')
      .where.not('skills.name': 'Unknown')
      .group('skills.name')
      .order(count: :desc)
      .count
      .first(10)

    @trims_guilds = Guild.where('gold_trims_count >= ?', 1)
      .order(gold_trims_count: :desc, silver_trims_count: :desc, bronze_trims_count: :desc)
      .first(16)

    @best_dpm_warriors = Player.warriors.order(average_dpm: :desc).first(5)
    @best_dpm_dervishes = Player.dervishs.order(average_dpm: :desc).first(5)
  end
end
