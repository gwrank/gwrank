require "test_helper"

module Teambuilds
  class IndexerTest < ActiveSupport::TestCase
    setup do
      @owner = create_player
      @teambuild = Teambuild.new(player: @owner, source_uuid: SecureRandom.uuid,
                                 visibility: "private", document: load_zcx)
      Indexer.call(@teambuild)
      @teambuild.save!
    end

    test "derives scalar columns" do
      assert_equal "GvG Split", @teambuild.name
      assert_equal %w[GvG], @teambuild.tags
      assert_equal "PvP", @teambuild.game_mode
      assert_equal 1, @teambuild.player_count
      assert_not_empty @teambuild.document_hash
    end

    test "derives root characters with professions, elite and dominant attribute" do
      row = @teambuild.teambuild_characters.sole
      assert_equal 0, row.position
      assert_equal "Water Snare", row.name
      assert_equal "Midline", row.assignment
      assert_equal professions(:elementalist).id, row.primary_profession_id
      assert_equal professions(:mesmer).id, row.secondary_profession_id
      assert_equal skills(:mist_form).id, row.elite_skill_id
      assert_equal "Water Magic", row.dominant_attribute
    end

    test "rebuild clears previous rows on reindex" do
      Indexer.call(@teambuild.reload)
      @teambuild.save!
      assert_equal 1, @teambuild.teambuild_characters.count
    end

    test "handles a second character with another elite" do
      doc = load_zcx
      doc["characters"] << {
        "id" => "33333333-3333-3333-3333-333333333333",
        "name" => "Trapper",
        "primaryProfession" => 2, "secondaryProfession" => 0,
        "assignment" => "", "notes" => "",
        "skillIds" => [946, 0, 0, 0, 0, 0, 0, 0],
        "attributes" => [{ "id" => 24, "points" => 9 }],
        "variants" => [], "titleRanks" => {}, "activeAttributeBoosts" => [],
        "isFavorite" => false, "gender" => 0, "durationBoostersEnabled" => false,
        "equipment" => nil
      }
      @teambuild.document = doc
      Indexer.call(@teambuild)
      @teambuild.save!
      rows = @teambuild.reload.teambuild_characters.order(:position)
      assert_equal 2, rows.count
      assert_equal skills(:trappers_focus).id, rows.second.elite_skill_id
      assert_equal "Wilderness Survival", rows.second.dominant_attribute
      assert_nil rows.second.secondary_profession_id
    end
  end
end
