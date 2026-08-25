require 'test_helper'

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    12.times { |i| create_match(played_at: Time.zone.now - i.days) }
  end

  test 'index limits matches to 10 per page' do
    get matches_path
    assert_response :success
    assert_equal 10, css_select('li[data-controller="match-builds"]').size
  end

  test 'index renders pagy nav when more than one page' do
    get matches_path
    assert_response :success
    assert_select 'div.gw-pagy'
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
end
