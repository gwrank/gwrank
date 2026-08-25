require "test_helper"

class DocumentationControllerTest < ActionDispatch::IntegrationTest
  test "GET /bot renders bot presentation with unified Discord invite" do
    get bot_path

    assert_response :success
    assert_select 'body', text: /GWRank Discord Bot/
    assert_select "a[href='https://discord.com/oauth2/authorize?client_id=788778440877801504']", text: 'Add Bot to Discord'
    assert_select "a[href='https://discord.gg/jqShPZBkcj']", text: 'Join our Discord'
    assert_select 'body', text: /Build Commands/
    assert_select 'body', text: /Team Build Commands/
    assert_select 'body', text: /How to Use the Bot/
  end
end
