require 'test_helper'

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    12.times { |i| create_match(played_at: Time.zone.now - i.days) }
  end

  test 'show renders for match without tournament' do
    match = create_match(tournament: nil)
    get match_path(match)
    assert_response :success
    assert_select 'div.gw-tabs' do
      assert_select 'a', text: 'Tournaments'
      assert_select 'span.gw-tab--active', text: match.title
    end
  end

  test 'show renders distinct builds for second team when served from cache' do
    guild_a = create_guild(name: 'Alpha Warlords')
    guild_b = create_guild(name: 'Beta Rangers')
    match = create_match(tournament: create_tournament, guild_a: guild_a, guild_b: guild_b)

    team_a, team_b = match.teams.order(:id)
    team_a.team_players.first.update!(profession: professions(:warrior), secondary_profession: professions(:monk))
    team_b.team_players.first.update!(profession: professions(:ranger), secondary_profession: nil)
    team_a.team_players.first.team_player_skills.create!(skill: skills(:water_attunement))
    team_b.team_players.first.team_player_skills.create!(skill: skills(:trappers_focus))

    old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    begin
      # Warm the cache exactly like MatchesController#show does
      Rails.cache.fetch("match_#{match.slug}", expires_in: 1.hour) do
        Match.includes(
          comments: [:player],
          teams: [
            :guild,
            { team_players: [:character, :player, :profession, :secondary_profession, :team_player_skills] }
          ]
        ).friendly.find(match.id)
      end

      get match_path(match)
      assert_response :success

      sections = css_select('section').select { |s| s.at_css('table.gw-table') }
      assert_equal 2, sections.size, 'expected one build section per team'

      alpha_html, beta_html = sections.map(&:to_html)
      assert_not_equal alpha_html, beta_html, 'both team build sections render identical HTML'

      assert_includes beta_html, 'Ranger', "second team section missing its own build"
      assert_not_includes beta_html, 'Warrior', 'second team section shows first team build'
    ensure
      Rails.cache = old_cache
    end
  end

  test 'index limits matches to 10 per page' do
    get matches_path
    assert_response :success
    assert_equal 10, css_select('li[data-controller="match-builds"]').size
  end

  test 'index renders pagy nav when more than one page' do
    get matches_path
    assert_response :success
    assert_select 'div.gw-pagy a', minimum: 1
  end

  test 'index renders remaining matches on page 2' do
    get matches_path(page: 2)
    assert_response :success
    assert_equal 2, css_select('li[data-controller="match-builds"]').size
  end

  test 'index responds successfully with active opponent filter' do
    get matches_path(opponent: 'Guild')
    assert_response :success
  end

  test "show renders shared template code popovers for team players" do
    match = create_match
    real_ignames = match.team_players.map { |tp| tp.read_attribute(:igname) }.compact
    assert real_ignames.present?, "expected persisted team player ignames to guard"
    get match_path(match)
    assert_response :success
    assert_select "[data-controller='template-code-popover']", count: 2
    assert_select "[data-template-code-popover-target='code']", minimum: 2
    page_text = response.body
    real_ignames.each do |igname|
      assert_not_includes page_text, igname, "real igname leaked to anonymous viewer"
    end
  end
end
