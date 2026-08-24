require "application_system_test_case"

class GwChromeTest < ApplicationSystemTestCase
  test "build library renders the GW chrome" do
    visit builds_url
    assert_selector "body.gw-body"
    assert_selector ".gw-window"
    assert_no_selector ".mpl-navbar"
  end
end
