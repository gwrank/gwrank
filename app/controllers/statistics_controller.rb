class StatisticsController < ApplicationController
  def index
    @most_picked_skills = TeamPlayerSkill.joins(:skill)
      .where.not('skills.name': 'No Skill')
      .where.not('skills.name': 'Unknown')
      .group('skills.name')
      .order(count: :desc)
      .count
      .first(25)
    
    @trims_guilds = Guild.where('gold_trims_count >= ?', 1)
      .order(gold_trims_count: :desc, silver_trims_count: :desc, bronze_trims_count: :desc)
      .first(16)
  end
end
