require "test_helper"

# == Schema Information
#
# Table name: teambuild_deletions
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime         not null
#  source_uuid :uuid             not null
#  visibility  :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  player_id   :bigint
#
# Indexes
#
#  index_teambuild_deletions_on_deleted_at                 (deleted_at)
#  index_teambuild_deletions_on_player_id                  (player_id)
#  index_teambuild_deletions_on_player_id_and_source_uuid  (player_id,source_uuid)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id) ON DELETE => nullify
#
class TeambuildDeletionTest < ActiveSupport::TestCase
  test "destroying a teambuild records a tombstone with visibility snapshot" do
    owner = create_player
    teambuild = Teambuild.create!(player: owner, source_uuid: SecureRandom.uuid,
                                  document: {}, visibility: "public")

    assert_difference -> { TeambuildDeletion.count }, 1 do
      teambuild.destroy!
    end

    tombstone = TeambuildDeletion.sole
    assert_equal owner.id, tombstone.player_id
    assert_equal teambuild.source_uuid, tombstone.source_uuid
    assert_equal "public", tombstone.visibility
  end

  test "visible_to exposes publics plus own deletions only" do
    owner = create_player
    other = create_player
    Teambuild.create!(player: owner, source_uuid: SecureRandom.uuid, document: {}).destroy!
    Teambuild.create!(player: other, source_uuid: SecureRandom.uuid,
                      document: {}, visibility: "public").destroy!
    Teambuild.create!(player: other, source_uuid: SecureRandom.uuid, document: {}).destroy!

    uuids = TeambuildDeletion.visible_to(owner).map(&:source_uuid)
    assert_equal 2, uuids.length
  end

  test "deleting a player account keeps public tombstones and nullifies ownership" do
    owner = create_player
    public_build = Teambuild.create!(player: owner, source_uuid: SecureRandom.uuid,
                                     document: {}, visibility: "public")
    private_build = Teambuild.create!(player: owner, source_uuid: SecureRandom.uuid, document: {})

    owner.destroy!

    assert_equal 2, TeambuildDeletion.count
    public_tombstone = TeambuildDeletion.find_by!(source_uuid: public_build.source_uuid)
    assert_nil public_tombstone.player_id
    assert_equal "public", public_tombstone.visibility
    private_tombstone = TeambuildDeletion.find_by!(source_uuid: private_build.source_uuid)
    assert_not_includes TeambuildDeletion.visible_to(create_player).map(&:source_uuid),
                        private_tombstone.source_uuid
  end

  test "re-ingesting a purged uuid clears its tombstones" do
    owner = create_player
    document = load_zcx
    result = Teambuilds::Ingest.call(player: owner, source_uuid: document["id"], document: document)
    raise "seed ingest failed: #{result.errors.inspect}" unless result.ok?
    result.teambuild.destroy!
    assert_equal 1, TeambuildDeletion.count

    Teambuilds::Ingest.call(player: owner, source_uuid: document["id"], document: document)

    assert_empty TeambuildDeletion.where(source_uuid: document["id"])
  end

  test "deleted_since filters by deletion instant" do
    player = create_player
    old = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {})
    travel_to(2.days.ago) { old.destroy! }
    recent = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {})
    recent.destroy!

    uuids = TeambuildDeletion.deleted_since(1.day.ago).map(&:source_uuid)
    assert_equal [recent.source_uuid], uuids
  end
end
