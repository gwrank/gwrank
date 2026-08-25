require "application_system_test_case"

class GwChromeTest < ApplicationSystemTestCase
  test "every main page renders the GW chrome without legacy styles" do
    [root_url, builds_url, tournaments_url, matches_url,
     players_url, scrims_url, guilds_url, statistics_url,
     streamers_url, player_doc_url, new_player_session_url].each do |url|
      visit url
      assert_selector "body.gw-body", wait: 2
      assert_no_selector ".mpl-navbar"
    end
  end

  test "build library renders the GW chrome" do
    visit builds_url
    assert_selector "body.gw-body"
    assert_selector ".gw-window"
    assert_no_selector ".mpl-navbar"
  end

  test "topbar search button opens the search dialog" do
    visit builds_url
    assert_no_selector "dialog[open]"
    find("button[aria-label='Search']").click
    assert_selector "dialog[open] input[name='q']"
  end

  test "mobile viewport exposes a scrollable main nav" do
    visit builds_url
    Capybara.current_session.current_window.resize_to(375, 812)
    assert_selector "header nav[aria-label='Main'] a.gw-tab", count: 3, visible: true
    find("header nav[aria-label='Main'] button[aria-label='Search']").click
    assert_selector "dialog[open]"
  ensure
    Capybara.current_session.current_window.resize_to(1400, 1400)
  end
end
