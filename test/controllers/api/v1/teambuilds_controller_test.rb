require "test_helper"

module Api::V1
  class TeambuildsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @owner = create_player
      @other = create_player
      @document = load_zcx
      put_doc(@owner, @document)
    end

    def json_headers(player)
      auth_headers(player).merge("Content-Type" => "application/json")
    end

    def put_doc(player, doc, visibility: nil)
      path = api_v1_teambuild_path(doc["id"])
      path += "?visibility=#{visibility}" if visibility
      put path, params: doc.to_json, headers: json_headers(player)
    end

    test "requires a token" do
      get api_v1_teambuilds_path
      assert_response :unauthorized
      get api_v1_teambuild_path(@document["id"])
      assert_response :unauthorized
    end

    test "index lists own privates and publics of everyone, not others' privates" do
      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_response :success
      assert_equal 1, response.parsed_body["pagination"]["totalCount"]

      public_doc = JSON.parse(@document.to_json)
      public_doc["id"] = "aaaaaaa1-0000-0000-0000-000000000001"
      public_doc["name"] = "Public Meta"
      put_doc(@other, public_doc, visibility: "public")

      hidden_doc = JSON.parse(@document.to_json)
      hidden_doc["id"] = "aaaaaaa1-0000-0000-0000-000000000002"
      hidden_doc["name"] = "Hidden Secret"
      put_doc(@other, hidden_doc)

      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      names = response.parsed_body["teambuilds"].map { |t| t["name"] }
      assert_includes names, "GvG Split"
      assert_includes names, "Public Meta"
      assert_not_includes names, "Hidden Secret"
    end

    test "show returns the raw stored document intact" do
      get api_v1_teambuild_path(@document["id"]), headers: auth_headers(@owner)
      assert_response :success
      assert_equal @document, response.parsed_body
    end

    test "show resolves by server id too" do
      get api_v1_teambuild_path(Teambuild.last.id), headers: auth_headers(@owner)
      assert_response :success
      assert_equal @document, response.parsed_body
    end

    test "show forbids other players' privates" do
      get api_v1_teambuild_path(@document["id"]), headers: auth_headers(@other)
      assert_response :forbidden
    end

    test "summary shape is camelCase with gw1 ids" do
      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      summary = response.parsed_body["teambuilds"].sole
      assert_equal "GvG Split", summary["name"]
      assert_equal @document["id"], summary["sourceId"]
      assert_equal 1, summary["playerCount"]
      assert_equal "PvP", summary["gameMode"]
      character = summary["characters"].sole
      assert_equal 6, character["primaryProfession"]
      assert_equal 5, character["secondaryProfession"]
      assert_equal 1064, character["eliteSkillId"]
      assert_equal "Water Magic", character["dominantAttribute"]
    end
  end
end
