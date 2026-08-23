require "test_helper"

# == Schema Information
#
# Table name: teambuilds
#
#  id            :bigint           not null, primary key
#  document      :jsonb            not null
#  document_hash :string
#  game_mode     :string           default("")
#  name          :string
#  player_count  :integer
#  source_uuid   :uuid             not null
#  status        :string           default("published"), not null
#  tags          :string           default([]), is an Array
#  visibility    :string           default("private"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  player_id     :bigint           not null
#
# Indexes
#
#  index_teambuilds_on_player_count               (player_count)
#  index_teambuilds_on_player_id                  (player_id)
#  index_teambuilds_on_player_id_and_source_uuid  (player_id,source_uuid) UNIQUE
#  index_teambuilds_on_status                     (status)
#  index_teambuilds_on_tags                       (tags) USING gin
#  index_teambuilds_on_updated_at                 (updated_at)
#  index_teambuilds_on_visibility                 (visibility)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id)
#
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

  test "status defaults to published and rejects unknown values" do
    player = create_player
    build = Teambuild.new(player: player, source_uuid: SecureRandom.uuid, document: {})
    assert_equal "published", build.status
    build.status = "brouillon"
    refute build.valid?
  end

  test "draft and published scopes filter by status" do
    player = create_player
    draft = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {}, status: "draft")
    published = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {})

    assert_equal [draft.id], Teambuild.draft.map(&:id)
    assert_includes Teambuild.published.map(&:id), published.id
    assert_not_includes Teambuild.published.map(&:id), draft.id
    assert_equal [draft.id], Teambuild.with_status("draft").map(&:id)
  end

  test "summary exposes status" do
    player = create_player
    teambuild = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {})
    assert_equal "published", teambuild.summary[:status]
  end
end
