require "application_system_test_case"

class GwChromeTest < ApplicationSystemTestCase
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
end
