require 'test_helper'

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = create_tournament
    @zelda_one = create_character(igname: 'Zelda One')
    @zelda_two = create_character(igname: 'Zelda Two')
    12.times do |i|
      match = create_match(tournament: @tournament, played_at: Time.zone.now - i.hours)
      character = i < 10 ? @zelda_one : @zelda_two
      match.teams.first.team_players.first.update(character: character)
    end
  end

  test 'limits match entries to 10 per page' do
    get search_path, params: { q: 'Zelda' }
    assert_response :success
    assert_equal 10, css_select('a.gw-row').size
  end

  test 'renders pagy nav on page 1 and remaining entries on page 2' do
    get search_path, params: { q: 'Zelda' }
    assert_select 'div.gw-pagy a', minimum: 1

    get search_path, params: { q: 'Zelda', page: 2 }
    assert_response :success
    assert_equal 2, css_select('a.gw-row').size
  end

  test 'single multisearch result redirects' do
    lone = create_character(igname: 'Unique Lone')
    match = create_match(tournament: @tournament)
    match.teams.second.team_players.first.update(character: lone)

    get search_path, params: { q: 'Unique' }
    assert_redirected_to match_path(match)
  end

  test 'query without results renders empty state' do
    get search_path, params: { q: 'NothingHere' }
    assert_response :success
    assert_select 'p.gw-empty'
  end

  test 'characters without joinable matches render empty state' do
    create_character(igname: 'Ghost One')
    create_character(igname: 'Ghost Two')
    get search_path, params: { q: 'Ghost' }
    assert_response :success
    assert_select 'p.gw-empty'
  end
end
