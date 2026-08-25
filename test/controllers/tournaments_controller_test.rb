require 'test_helper'

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = create_tournament
    12.times do |i|
      create_match(tournament: @tournament, played_at: Time.zone.now - i.hours,
                   round: 1, number_on_round: i + 1)
    end
  end

  test 'show limits tournament matches to 10 per page' do
    get tournament_path(@tournament)
    assert_response :success
    assert_equal 10, css_select('li[data-controller="match-builds"]').size
  end

  test 'show renders pagy nav when more than one page' do
    get tournament_path(@tournament)
    assert_response :success
    assert_select 'div.gw-pagy a', minimum: 1
  end

  test 'show renders remaining matches on page 2' do
    get tournament_path(@tournament, page: 2)
    assert_response :success
    assert_equal 2, css_select('li[data-controller="match-builds"]').size
  end

  test 'old tournament renders show_old without pagination' do
    old = Tournament.create!(tournament_type: 'mat', year: 2019, month: 5,
                             date: Date.new(2019, 5, 10))
    create_match(tournament: old)
    get tournament_path(old)
    assert_response :success
    assert_select 'div.gw-pagy', count: 0
    assert_equal 0, css_select('li[data-controller="match-builds"]').size
  end
end
