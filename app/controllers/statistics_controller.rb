class StatisticsController < ApplicationController
  def index
    @most_picked_skills = TeamPlayerSkill.joins(:skill)
                                         .where.not('skills.name': 'No Skill')
                                         .where.not('skills.name': 'Unknown')
                                         .group('skills.name')
                                         .order(count: :desc)
                                         .count
                                         .first(25)
  end
end
