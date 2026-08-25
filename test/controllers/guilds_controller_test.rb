require 'test_helper'

class GuildsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guild = create_guild
    @tournament = create_tournament
    12.times do |i|
      create_match(tournament: @tournament, played_at: Time.zone.now - i.hours,
                   guild_a: @guild)
    end
  end

  test 'show limits guild matches to 10 per page' do
    get guild_path(@guild)
    assert_response :success
    assert_equal 10, css_select('tbody tr').size
  end

  test 'show renders pagy nav when more than one page' do
    get guild_path(@guild)
    assert_response :success
    assert_select 'div.gw-pagy a', minimum: 1
  end

  test 'show renders remaining matches on page 2' do
    get guild_path(@guild, page: 2)
    assert_response :success
    assert_equal 2, css_select('tbody tr').size
  end

  test 'show hides matches section for guild without teams' do
    lonely = create_guild
    get guild_path(lonely)
    assert_response :success
    assert_select 'div.gw-pagy', count: 0
  end
end
