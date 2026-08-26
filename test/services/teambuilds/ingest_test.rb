require "test_helper"

module Teambuilds
  class IngestTest < ActiveSupport::TestCase
    setup do
      @owner = create_player
      @doc = load_zcx
    end

    def ingest(document, visibility: "private", source_uuid: @doc["id"], status: nil)
      Ingest.call(player: @owner, source_uuid: source_uuid, document: document,
                  visibility: visibility, status: status)
    end

    test "creates a teambuild and derived indexes" do
      result = ingest(@doc)
      assert result.ok?
      assert result.created?
      teambuild = @owner.teambuilds.sole
      assert_equal "private", teambuild.visibility
      assert_equal 1, teambuild.teambuild_characters.count
    end

    test "is a no-op when only updatedAt changes" do
      ingest(@doc)
      before = @owner.teambuilds.sole.updated_at
      touched = JSON.parse(@doc.to_json)
      touched["updatedAt"] = "2030-01-01T00:00:00Z"
      result = ingest(touched)
      assert result.ok?
      assert_not result.created?
      assert_not result.changed?
      assert_equal before, @owner.teambuilds.sole.reload.updated_at
    end

    test "replaces when the document really changes" do
      ingest(@doc)
      changed = JSON.parse(@doc.to_json)
      changed["name"] = "GvG Split v2"
      result = ingest(changed)
      assert result.changed?
      assert_equal "GvG Split v2", @owner.teambuilds.sole.reload.name
      assert_equal 1, @owner.teambuilds.count
    end

    test "keeps separate identities per owner and rejects invalid input" do
      other = create_player
      ingest(@doc)
      other_result = Ingest.call(player: other, source_uuid: @doc["id"], document: @doc)
      assert other_result.ok?

      broken = JSON.parse(@doc.to_json)
      broken["Name"] = "oops"
      result = ingest(broken)
      assert_not result.ok?
      assert_equal ["wrong_case"], result.errors.map { |e| e["code"] }
      assert_equal "GvG Split", @owner.teambuilds.sole.reload.name
    end

    test "round-trips the exact document through storage" do
      ingest(@doc)
      assert_equal @doc, @owner.teambuilds.sole.reload.document
    end

    test "applies a visibility change even when the document is unchanged" do
      ingest(@doc)
      teambuild = @owner.teambuilds.sole
      before = teambuild.updated_at
      result = ingest(@doc, visibility: "public")
      assert result.ok?
      assert_not result.changed?
      assert_equal "public", teambuild.reload.visibility
      assert_equal before, teambuild.reload.updated_at
    end

    test "rejects a non-canonical source uuid" do
      result = ingest(@doc, source_uuid: "Not-A-UUID")
      assert_not result.ok?
      assert_equal ["invalid_source_uuid"], result.errors.map { |e| e["code"] }
    end

    test "defaults status to published on creation" do
      ingest(@doc)
      assert_equal "published", @owner.teambuilds.sole.status
    end

    test "persists an explicit draft status" do
      result = ingest(@doc, status: "draft")
      assert result.ok?
      assert_equal "draft", @owner.teambuilds.sole.reload.status
    end

    test "applies status changes without flipping changed?" do
      ingest(@doc, status: "draft")
      result = ingest(@doc)
      assert result.ok?
      assert_not result.changed?
      assert_equal "draft", @owner.teambuilds.sole.reload.status

      result = ingest(@doc, status: "published")
      assert_not result.changed?
      assert_equal "published", @owner.teambuilds.sole.reload.status
    end

    test "keeps the current status when replaced without the param" do
      ingest(@doc, status: "draft")
      changed = JSON.parse(@doc.to_json)
      changed["name"] = "GvG Split v2"
      ingest(changed)
      assert_equal "draft", @owner.teambuilds.sole.reload.status
    end

    test "ignores unknown status values" do
      ingest(@doc, status: "draft")
      ingest(@doc, status: "brouillon")
      assert_equal "draft", @owner.teambuilds.sole.reload.status
    end

    test "flags precondition_failed on a stale If-Match" do
      ingest(@doc)
      result = Ingest.call(
        player: @owner, source_uuid: @doc["id"],
        document: JSON.parse(@doc.to_json).merge("name" => "x"),
        if_match: "0" * 64
      )
      assert_not result.ok?
      assert result.precondition_failed?
    end

    test "accepts a matching If-Match and star" do
      ingest(@doc)
      hash = @owner.teambuilds.sole.document_hash
      result = Ingest.call(player: @owner, source_uuid: @doc["id"], document: @doc, if_match: hash)
      assert result.ok?
      result = Ingest.call(player: @owner, source_uuid: @doc["id"], document: @doc, if_match: "*")
      assert result.ok?
    end

    test "rejects ingestion of a build tagged outside the closed list" do
      doc = load_zcx
      doc["id"] = "ccccccc1-0000-0000-0000-000000000001"
      doc["tags"] = ["GvG", "CustomTag"]
      result = Ingest.call(player: create_player, source_uuid: doc["id"], document: doc)
      refute result.ok?
      error = result.errors.find { |e| e["code"] == "invalid_tag" }
      assert_includes error["message"], "CustomTag"
    end
  end
end
