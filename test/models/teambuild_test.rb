require "test_helper"

class TeambuildTest < ActiveSupport::TestCase
  test "visibility accepts only private or public" do
    player = create_player
    build = Teambuild.new(player: player, source_uuid: SecureRandom.uuid,
                          visibility: "internal", document: {})
    refute build.valid?
    build.visibility = "public"
    assert build.valid?
  end

  test "player_count is bounded to 0..12" do
    player = create_player
    build = Teambuild.new(player: player, source_uuid: SecureRandom.uuid,
                          document: {}, player_count: 13)
    refute build.valid?
  end

  test "visible_to returns publics plus own privates" do
    owner = create_player
    other = create_player
    own_private = Teambuild.create!(player: owner, source_uuid: SecureRandom.uuid, document: {})
    public_other = Teambuild.create!(player: other, source_uuid: SecureRandom.uuid, document: {}, visibility: "public")
    private_other = Teambuild.create!(player: other, source_uuid: SecureRandom.uuid, document: {})

    ids = Teambuild.visible_to(owner).map(&:id)
    assert_includes ids, own_private.id
    assert_includes ids, public_other.id
    assert_not_includes ids, private_other.id
  end

  test "search scopes filter by name and tags" do
    player = create_player
    gvg = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {},
                            name: "GvG Split", tags: ["GvG", "meta"])
    Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {},
                      name: "HA Ball", tags: ["HA"])

    assert_includes Teambuild.with_name_like("gvg").map(&:id), gvg.id
    assert_equal [gvg.id], Teambuild.tagged_with_any(["meta"]).map(&:id)
  end

  test "visible_to tolerates nil player by returning publics only" do
    other = create_player
    public_other = Teambuild.create!(player: other, source_uuid: SecureRandom.uuid, document: {}, visibility: "public")
    private_other = Teambuild.create!(player: other, source_uuid: SecureRandom.uuid, document: {})

    ids = Teambuild.visible_to(nil).map(&:id)
    assert_includes ids, public_other.id
    assert_not_includes ids, private_other.id
  end

  test "source_uuid is unique per player" do
    player = create_player
    source_uuid = SecureRandom.uuid
    Teambuild.create!(player: player, source_uuid: source_uuid, document: {})
    duplicate = Teambuild.new(player: player, source_uuid: source_uuid, document: {})
    refute duplicate.valid?
  end
end
