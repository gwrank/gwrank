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

    def put_doc(player, doc, visibility: nil, status: nil)
      query = { visibility: visibility, status: status }.compact
      path = api_v1_teambuild_path(doc["id"])
      path += "?#{query.to_query}" unless query.empty?
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
      assert_equal @document, response.parsed_body.except("author")
      assert_equal @owner.username, response.parsed_body["author"]
    end

    test "show resolves by server id too" do
      get api_v1_teambuild_path(Teambuild.last.id), headers: auth_headers(@owner)
      assert_response :success
      assert_equal @document, response.parsed_body.except("author")
      assert_equal @owner.username, response.parsed_body["author"]
    end

    test "show forbids other players' privates" do
      get api_v1_teambuild_path(@document["id"]), headers: auth_headers(@other)
      assert_response :forbidden
    end

    test "summary shape is camelCase with gw1 ids" do
      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      summary = response.parsed_body["teambuilds"].sole
      assert_equal "GvG Split", summary["name"]
      assert_equal @owner.username, summary["author"]
      assert_equal @document["id"], summary["sourceId"]
      assert_equal 1, summary["playerCount"]
      assert_equal "PvP", summary["gameMode"]
      character = summary["characters"].sole
      assert_equal 6, character["primaryProfession"]
      assert_equal 5, character["secondaryProfession"]
      assert_equal 1064, character["eliteSkillId"]
      assert_equal "Water Magic", character["dominantAttribute"]
    end

    test "summaries expose documentHash and show sets a strong ETag" do
      hash = Teambuild.last.document_hash

      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_equal hash, response.parsed_body["teambuilds"].sole["documentHash"]

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_equal hash, response.parsed_body["teambuilds"].sole["documentHash"]

      get api_v1_teambuild_path(@document["id"]), headers: auth_headers(@owner)
      assert_response :success
      assert_equal %("#{hash}"), response.headers["ETag"]
    end

    test "upsert creates then no-op then replaces" do
      fresh = JSON.parse(@document.to_json)
      fresh["id"] = "eeeeeee1-0000-0000-0000-000000000001"
      put_doc(@owner, fresh)
      assert_response :created
      assert_equal true, response.parsed_body["created"]
      assert_equal @owner.username, response.parsed_body["author"]

      before = Teambuild.last.updated_at
      touched = JSON.parse(@document.to_json)
      touched["id"] = "eeeeeee1-0000-0000-0000-000000000001"
      touched["updatedAt"] = "2030-01-01T00:00:00Z"
      put_doc(@owner, touched)
      assert_response :success
      assert_equal false, response.parsed_body["created"]
      assert_equal before, Teambuild.last.reload.updated_at

      changed = JSON.parse(@document.to_json)
      changed["id"] = "eeeeeee1-0000-0000-0000-000000000001"
      changed["name"] = "GvG Split v2"
      put_doc(@owner, changed)
      assert_response :success
      assert_equal false, response.parsed_body["created"]
      assert_equal "GvG Split v2", Teambuild.last.reload.name
    end

    test "upsert defaults to private and honors visibility param" do
      assert_equal "private", Teambuild.last.visibility
      doc = JSON.parse(@document.to_json)
      doc["id"] = "bbbbbbb1-0000-0000-0000-000000000001"
      put_doc(@other, doc, visibility: "public")
      assert_response :created
      assert_equal "public", Teambuild.find_by(source_uuid: doc["id"]).visibility
      assert_equal true, response.parsed_body["changed"]
    end

    test "upsert accepts a status param and summaries expose it" do
      fresh = JSON.parse(@document.to_json)
      fresh["id"] = "fffffff1-0000-0000-0000-000000000001"
      fresh["name"] = "Draft Split"
      put_doc(@owner, fresh, status: "draft")
      assert_response :created
      assert_equal "draft", response.parsed_body["status"]

      get api_v1_teambuilds_path(status: "draft"), headers: auth_headers(@owner)
      assert_equal ["Draft Split"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get api_v1_teambuilds_path(status: "published"), headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |t| t["name"] }, "GvG Split"
    end

    test "upsert accepts free-form tags, keeps them in export, filters stay canonical" do
      doc = JSON.parse(@document.to_json)
      doc["id"] = "eeeeeee2-0000-0000-0000-000000000001"
      doc["name"] = "Free Tagged"
      doc["tags"] = ["meta", "gvg", "guild name"]
      put_doc(@owner, doc)
      assert_response :created

      get api_v1_teambuilds_path(tags: "GvG"), headers: auth_headers(@owner)
      names = response.parsed_body["teambuilds"].map { |t| t["name"] }
      assert_includes names, "Free Tagged"
      assert_includes names, "GvG Split"

      get api_v1_teambuilds_path(q: "free tagged"), headers: auth_headers(@owner)
      assert_equal ["Free Tagged"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      mine = response.parsed_body["teambuilds"].find { |entry| entry["sourceId"] == doc["id"] }
      assert_equal ["meta", "GvG", "guild name"], mine["tags"]
    end

    test "index ignores invalid status filters" do
      get api_v1_teambuilds_path(status: "brouillon"), headers: auth_headers(@owner)
      assert_response :success
      assert_equal 1, response.parsed_body["pagination"]["totalCount"]
    end

    test "upsert rejects malformed json and non-canonical uuid" do
      put api_v1_teambuild_path(@document["id"]),
          params: "{oops", headers: auth_headers(@owner).merge("Content-Type" => "application/json")
      assert_response :bad_request
      put api_v1_teambuild_path("not-a-uuid"),
          params: "{}", headers: auth_headers(@owner).merge("Content-Type" => "application/json")
      assert_response :bad_request
    end

    test "upsert rejects documents violating format rules" do
      cases = {
        "null_array" => ->(d) { d["characters"] = nil },
        "wrong_case" => ->(d) { d["Name"] = "x" },
        "duplicate_attribute_id" => lambda { |d|
          d["characters"][0]["attributes"] << { "id" => 11, "points" => 5 }
        },
        "invalid_skill_ids" => ->(d) { d["characters"][0]["skillIds"].pop },
        "too_many_characters" => lambda { |d|
          extra = d["characters"][0].dup
          12.times { d["characters"] << extra }
        }
      }
      cases.each do |expected_code, mutate|
        doc = JSON.parse(@document.to_json)
        mutate.call(doc)
        put_doc(@owner, doc)
        assert_response :unprocessable_entity, "attendu 422 pour #{expected_code}"
        codes = response.parsed_body["errors"].map { |error| error["code"] }
        assert_includes codes, expected_code
      end
      assert_equal 1, Teambuild.count
    end

    test "destroy allows only the owner" do
      delete api_v1_teambuild_path(@document["id"]), headers: auth_headers(@other)
      assert_response :forbidden
      delete api_v1_teambuild_path(@document["id"]), headers: auth_headers(@owner)
      assert_response :no_content
      assert_nil Teambuild.find_by(source_uuid: @document["id"])
    end

    test "destroy returns 404 when missing" do
      delete api_v1_teambuild_path("ccccccc1-0000-0000-0000-000000000001"),
             headers: auth_headers(@owner)
      assert_response :not_found
    end

    test "index filters combine correctly" do
      public_doc = JSON.parse(@document.to_json)
      public_doc["id"] = "ddddddd1-0000-0000-0000-000000000001"
      public_doc["name"] = "Ranger Trap"
      public_doc["tags"] = ["HA"]
      public_doc["gameMode"] = "PvE"
      public_doc["characters"][0] = {
        "id" => "44444444-4444-4444-4444-444444444444",
        "name" => "Barrage", "primaryProfession" => 2, "secondaryProfession" => 0,
        "isFavorite" => false, "assignment" => "", "gender" => 0,
        "skillIds" => [946, 0, 0, 0, 0, 0, 0, 0],
        "attributes" => [{ "id" => 25, "points" => 12 }],
        "titleRanks" => {}, "equipment" => nil, "notes" => "",
        "durationBoostersEnabled" => false, "activeAttributeBoosts" => [], "variants" => []
      }
      put_doc(@other, public_doc, visibility: "public")

      get api_v1_teambuilds_path(q: "ranger"), headers: auth_headers(@owner)
      assert_equal ["Ranger Trap"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get api_v1_teambuilds_path(profession_id: professions(:ranger).profession_id),
          headers: auth_headers(@owner)
      assert_equal ["Ranger Trap"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get api_v1_teambuilds_path(elite_skill_id: skills(:mist_form).skill_id),
          headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |t| t["name"] }, "GvG Split"

      get api_v1_teambuilds_path(campaign: "Nightfall"), headers: auth_headers(@owner)
      assert_equal ["Ranger Trap"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get api_v1_teambuilds_path(tags: "GvG"), headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |t| t["name"] }, "GvG Split"

      get api_v1_teambuilds_path(game_mode: "PvE"), headers: auth_headers(@owner)
      assert_equal ["Ranger Trap"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get api_v1_teambuilds_path(player_count_max: 1, sort: "name"),
          headers: auth_headers(@owner)
      names = response.parsed_body["teambuilds"].map { |t| t["name"] }
      assert_equal names.sort, names

      get api_v1_teambuilds_path(visibility: "mine"), headers: auth_headers(@owner)
      assert_equal ["GvG Split"], response.parsed_body["teambuilds"].map { |t| t["name"] }
    end

    test "filters accept gw1 canonical ids" do
      get api_v1_teambuilds_path(profession_id: 6), headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |t| t["name"] }, "GvG Split"

      get api_v1_teambuilds_path(elite_skill_id: 1064), headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |t| t["name"] }, "GvG Split"

      get api_v1_teambuilds_path(profession_id: 999), headers: auth_headers(@owner)
      assert_empty response.parsed_body["teambuilds"]

      get api_v1_teambuilds_path(elite_skill_id: 123_456), headers: auth_headers(@owner)
      assert_empty response.parsed_body["teambuilds"]
    end

    test "export requires a token" do
      get export_api_v1_teambuilds_path
      assert_response :unauthorized
    end

    test "export returns visible builds with intact documents" do
      public_doc = JSON.parse(@document.to_json)
      public_doc["id"] = "aaaaaaa1-0000-0000-0000-000000000009"
      put_doc(@other, public_doc, visibility: "public")

      hidden_doc = JSON.parse(@document.to_json)
      hidden_doc["id"] = "aaaaaaa1-0000-0000-0000-000000000008"
      put_doc(@other, hidden_doc)

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_response :success
      entries = response.parsed_body["teambuilds"]
      ids = entries.map { |entry| entry["sourceId"] }
      assert_includes ids, @document["id"]
      assert_includes ids, public_doc["id"]
      assert_not_includes ids, hidden_doc["id"]
      assert_equal @other.username, entries.first["author"]

      mine = entries.find { |entry| entry["sourceId"] == @document["id"] }
      assert_equal @document, mine["document"]
      assert_equal "published", mine["status"]
      assert_equal 1, mine["playerCount"]
    end

    test "export includes others' public drafts and supports the status filter" do
      draft_doc = JSON.parse(@document.to_json)
      draft_doc["id"] = "bbbbbbb1-0000-0000-0000-000000000007"
      put_doc(@other, draft_doc, visibility: "public", status: "draft")

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |e| e["sourceId"] }, draft_doc["id"]

      get export_api_v1_teambuilds_path(status: "draft"), headers: auth_headers(@owner)
      assert_equal [draft_doc["id"]],
                   response.parsed_body["teambuilds"].map { |e| e["sourceId"] }
    end

    test "export can be empty" do
      Teambuild.destroy_all
      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_response :success
      assert_empty response.parsed_body["teambuilds"]
    end
  end
end
