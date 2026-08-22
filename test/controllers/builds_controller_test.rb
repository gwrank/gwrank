require "test_helper"

class BuildsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = create_player
    @other = create_player
    @document = load_zcx
    Teambuilds::Ingest.call(player: @owner, source_uuid: @document["id"],
                            document: @document, visibility: "private")
  end

  test "anonymous index lists only public builds" do
    get builds_path
    assert_response :success
    assert_select "body", { text: /GvG Split/, count: 0 }
  end

  test "signed-in owner sees their private build listed" do
    sign_in @owner
    get builds_path
    assert_response :success
    assert_select "body", text: /GvG Split/
  end

  test "show redirects anonymous users away from private builds" do
    get build_path(Teambuild.last)
    assert_redirected_to builds_path
  end

  test "owner can view and download their private build" do
    sign_in @owner
    teambuild = Teambuild.last
    get build_path(teambuild)
    assert_response :success
    assert_select "body", text: /Water Snare/

    get download_build_path(teambuild)
    assert_response :success
    assert_equal "attachment", response.headers["Content-Disposition"].split(";").first.strip
    assert_equal @document, JSON.parse(response.body)
  end

  test "download is denied for other players" do
    sign_in @other
    get download_build_path(Teambuild.last)
    assert_redirected_to builds_path
  end
end
