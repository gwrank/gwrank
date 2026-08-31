require "application_system_test_case"

class MatchesSystemTest < ApplicationSystemTestCase
  setup do
    @match = create_match
  end

  def match_row
    "li[data-match-builds-match-id-value='#{@match.id}']"
  end

  def toggle_selector
    "#{match_row} button[data-match-builds-target='toggle']"
  end

  def popup_selector
    "#match-builds-popup-#{@match.id}"
  end

  test "match builds popup opens and closes" do
    visit matches_url

    assert_selector popup_selector, visible: false
    assert_selector "#{toggle_selector}[aria-expanded='false']"

    find(toggle_selector).click

    assert_selector popup_selector, visible: true
    assert_selector "#{toggle_selector}[aria-expanded='true']"

    find(toggle_selector).send_keys(:escape)

    assert_selector popup_selector, visible: false
    assert_selector "#{toggle_selector}[aria-expanded='false']"
  end

  test "match builds popup closes when clicking outside the row" do
    visit matches_url

    find(toggle_selector).click
    assert_selector popup_selector, visible: true

    find("h1").click

    assert_selector popup_selector, visible: false
    assert_selector "#{toggle_selector}[aria-expanded='false']"
  end
end
