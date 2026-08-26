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
    assert_includes response.headers["Content-Disposition"], "filename=\"gvg-split.zcx\""
    assert_equal @document, JSON.parse(response.body)
  end

  test "download is denied for other players" do
    sign_in @other
    get download_build_path(Teambuild.last)
    assert_redirected_to builds_path
  end

  test "public drafts carry a Draft badge" do
    doc = JSON.parse(@document.to_json)
    doc["id"] = "ddddddd9-0000-0000-0000-000000000001"
    Teambuilds::Ingest.call(player: @other, source_uuid: doc["id"], document: doc,
                            visibility: "public", status: "draft")
    draft = Teambuild.find_by(source_uuid: doc["id"])

    get builds_path
    assert_select ".gw-badge--draft", text: "Draft", count: 1

    get build_path(draft)
    assert_select ".gw-badge--draft", text: "Draft", count: 1
  end

  test "index renders the GW window structure" do
    sign_in @owner
    get builds_path
    assert_response :success
    assert_select "main .gw-window", count: 1
    assert_select ".gw-row", count: 1
    assert_select ".gw-badge--mode", text: "PvP"
    assert_select ".gw-badge--tag", text: "GvG"
    assert_select ".gw-row img", minimum: 1
    assert_select ".gw-topbar"
    assert_select ".gw-row", text: /@#{Regexp.escape(@owner.username)}/
  end

  test "index renders all eight profession icons on one row" do
    doc = load_zcx("eight_man")
    Teambuilds::Ingest.call(player: @owner, source_uuid: doc["id"], document: doc,
                            visibility: "public")
    get builds_path
    assert_response :success
    assert_select ".gw-row", text: /Eight Man Test/ do
      assert_select "img", count: 8
    end
    assert_select ".gw-row", text: /updated \d{2}\/\d{2}\/\d{4}/
  end

  test "index shows an empty state when nothing matches" do
    sign_in @owner
    get builds_path, params: { q: "inexistant" }
    assert_response :success
    assert_select ".gw-empty"
  end

  test "show renders compact rows with skills, attributes, notes and template popovers" do
    sign_in @owner
    get build_path(Teambuild.last)
    assert_response :success
    assert_select "table.gw-table tbody tr", minimum: 1
    assert_select "tbody img[width='32']", minimum: 8
    assert_select "ul li strong", minimum: 1
    assert_select "tbody p.text-note", text: /Élémentaliste/
    assert_select "tbody .gw-badge--mode", text: "Midline"
    assert_select "[data-controller='template-code-popover']", minimum: 1
    assert_select "[data-template-code-popover-target='code']", minimum: 1
    assert_select ".gw-window-header small", text: /@#{Regexp.escape(@owner.username)}/
  end

  test "show renders base characters only when build has no locks" do
    doc = load_zcx
    doc["id"] = "ddddddd9-0000-0000-0000-000000000003"
    doc["locks"] = []
    doc["characters"][0]["variants"] = [doc["characters"][0].dup.merge("name" => "Variant One")]
    Teambuilds::Ingest.call(player: @owner, source_uuid: doc["id"], document: doc, visibility: "private")

    sign_in @owner
    get build_path(Teambuild.find_by!(source_uuid: doc["id"]))
    assert_response :success
    assert_select "tbody tr td > span > strong", text: /Water Snare/, count: 1
    assert_select "tbody tr td > span > strong", text: /Variant One/, count: 0
  end

  test "hides template code trigger for characters without professions" do
    doc = load_zcx
    doc["id"] = "ddddddd9-0000-0000-0000-000000000002"
    doc["characters"][0]["primaryProfession"] = 0
    doc["characters"][0]["secondaryProfession"] = 0
    Teambuilds::Ingest.call(player: @owner, source_uuid: doc["id"], document: doc, visibility: "public")
    sign_in @owner
    get build_path(Teambuild.find_by!(source_uuid: doc["id"]))
    assert_response :success
    assert_select "[data-controller='template-code-popover']", count: 0
  end

  test "show renders one locked composition panel per resolvable lock" do
    doc = load_zcx("variants_with_locks")
    Teambuilds::Ingest.call(player: @owner, source_uuid: doc["id"], document: doc, visibility: "private")

    sign_in @owner
    get build_path(Teambuild.find_by!(source_uuid: doc["id"]))
    assert_response :success

    assert_select "[data-variant-tabs-target='tab']", count: 2
    assert_select "[data-variant-tabs-target='panel']", count: 2

    assert_select "div[data-composition-id='composition-1'] tbody tr td strong", text: "One Mid"
    assert_select "div[data-composition-id='composition-1'] img[title='Example Ward']"
    assert_select "div[data-composition-id='composition-2'] tbody tr td strong", text: "One Deep"
    assert_select "div[data-composition-id=\"composition-2\"] img[title=\"Trapper's Focus Example\"]"
    assert_select "div[data-composition-id='composition-2'] tbody tr", count: 2
  end
end
