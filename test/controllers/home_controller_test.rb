require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the showcase homepage" do
    get root_path

    assert_response :success
    assert_select 'body', text: /Builds, teambuilds and a Discord bot — everything your guild needs to prepare its GvG matches\./
    assert_select "a[href='https://discord.com/oauth2/authorize?client_id=788778440877801504']", text: 'Add Bot to Discord'
    assert_select "a[href='/builds']", text: 'Browse Builds'
    assert_select 'body', text: /Build & Teambuild Library/
    assert_select 'body', text: /Discord Bot/
    assert_select 'body', text: /Open Scrims/
    assert_select 'body', text: /Tournament Archives/
    assert_select 'body', text: /Documentation/
  end
end
