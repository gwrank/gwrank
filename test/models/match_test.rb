require 'test_helper'

class MatchTest < ActiveSupport::TestCase
  test 'title uses preloaded teams without extra queries' do
    match = create_match
    preloaded = Match.where(id: match.id).includes(teams: :guild).first
    expected_title = match_title_for(match)
    assert_no_queries { assert_equal expected_title, preloaded.title }
  end

  test 'title falls back to batched includes when teams are not loaded' do
    match = create_match
    fresh = Match.find(match.id)
    assert_equal match_title_for(match), fresh.title
  end

  private

  def match_title_for(match)
    "#{match.teams.first.guild.name_with_tag} vs. #{match.teams.second.guild.name_with_tag}"
  end
end
