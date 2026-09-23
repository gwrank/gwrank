require "test_helper"
require "base64"
require "digest"

module Rooms
  class SessionStoreTest < ActiveSupport::TestCase
    class RecordingCache < ActiveSupport::Cache::MemoryStore
      attr_reader :writes

      def initialize
        super
        @writes = []
      end

      def write(name, value, options = nil)
        @writes << { name: name, value: value, options: options || {} }
        super
      end
    end

    setup do
      @now = Time.utc(2026, 9, 23, 16)
      @cache = RecordingCache.new
      @lock_keys = []
      @store = SessionStore.new(
        cache: @cache,
        clock: -> { @now },
        locker: ->(key, &block) { @lock_keys << key; block.call }
      )
    end

    test "defines the shared room limits and durations" do
      assert_equal 8, SessionStore::MAX_PARTICIPANTS
      assert_equal 100, SessionStore::MAX_ACTIVE_ROOMS
      assert_equal 2.hours, SessionStore::ROOM_TTL
      assert_equal 5.minutes, SessionStore::CREATOR_GRACE
      assert_equal 90.seconds, SessionStore::PRESENCE_LEASE
      assert_equal 10, SessionStore::MESSAGES_PER_SECOND
    end

    test "creates a snapshot with the documented shape and an indexed expiry" do
      result = @store.create!
      snapshot = @cache.read(snapshot_key(result[:code]))
      expires_at = @now + SessionStore::ROOM_TTL

      assert_match(/\A[A-Z2-9]{4}-[A-Z2-9]{3}\z/, result[:code])
      refute_match(/[ILO]/, result[:code])
      assert_match(/\A[A-Za-z0-9_-]{43}\z/, result[:creator_secret])
      assert_equal expires_at, result[:expires_at]
      assert_equal({
        "creatorDigest" => Digest::SHA256.hexdigest(result[:creator_secret]),
        "createdAt" => @now.iso8601(6),
        "expiresAt" => expires_at.iso8601(6),
        "creatorConnectionId" => nil,
        "creatorGraceUntil" => nil,
        "members" => {},
        "stateVersion" => 0,
        "lastPayload" => nil,
        "rateWindowStartedAt" => @now.iso8601(6),
        "rateCount" => 0
      }, snapshot)
      assert_equal({ result[:code] => expires_at.iso8601(6) }, @cache.read(SessionStore::INDEX_KEY))
      assert_equal Digest::SHA256.hexdigest(result[:creator_secret]), snapshot.fetch("creatorDigest")
      refute snapshot.values.include?(result[:creator_secret])
      assert_equal "gwrank:rooms:lock:v1:index", @lock_keys.first
    end

    test "writes snapshot and index with the remaining absolute lifetime" do
      result = @store.create!
      creation_writes = @cache.writes.select { |write| write[:name] == snapshot_key(result[:code]) }

      assert_equal 1, creation_writes.length
      assert_equal SessionStore::ROOM_TTL, creation_writes.first[:options].fetch(:expires_in)

      @now += 30.seconds
      @store.join!(code: result[:code], connection_id: "conn-1")
      latest_snapshot_write = @cache.writes.reverse.find do |write|
        write[:name] == snapshot_key(result[:code])
      end

      assert_equal SessionStore::ROOM_TTL - 30.seconds, latest_snapshot_write[:options].fetch(:expires_in)
    end

    test "persists subsecond timestamps for expiry and rate windows" do
      @now += 0.75.seconds
      created = @store.create!
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_equal @now.iso8601(6), snapshot.fetch("createdAt")
      assert_equal created[:expires_at].iso8601(6), snapshot.fetch("expiresAt")
      assert_equal @now.iso8601(6), snapshot.fetch("rateWindowStartedAt")

      @store.join!(code: created[:code], connection_id: "conn-1")
      snapshot = @cache.read(snapshot_key(created[:code]))
      assert_equal @now.iso8601(6), snapshot.fetch("members").fetch("conn-1").fetch("lastSeen")

      10.times { @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "OLD") }
      @now += 0.5.seconds
      assert_raises(SessionStore::Error) do
        @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "TOO-SOON")
      end
    end

    test "keeps a member alive just under the presence lease boundary" do
      @now += 0.75.seconds
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "conn-1")
      @now += SessionStore::PRESENCE_LEASE - 0.25.seconds

      result = @store.join!(code: created[:code], connection_id: "conn-2")

      assert_equal ["conn-1", "conn-2"], result[:participants]
    end

    test "keeps creator grace alive just under its subsecond boundary" do
      @now += 0.75.seconds
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "creator", creator_secret: created[:creator_secret])
      @store.join!(code: created[:code], connection_id: "observer")
      @store.leave!(code: created[:code], connection_id: "creator")
      grace_until = @now + SessionStore::CREATOR_GRACE
      @now += SessionStore::CREATOR_GRACE - 0.25.seconds

      result = @store.touch!(code: created[:code], connection_id: "observer")
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_nil result[:expired_reason]
      assert_equal grace_until.iso8601(6), snapshot.fetch("creatorGraceUntil")
      assert_equal ["observer"], @store.join!(code: created[:code], connection_id: "observer")[:participants]
    end

    test "persists the pruned index before raising rooms_full" do
      100.times { @store.create! }
      index = @cache.read(SessionStore::INDEX_KEY)
      index["STALE"] = (@now - 1.second).iso8601
      @cache.write(SessionStore::INDEX_KEY, index, expires_in: 1.hour)

      error = assert_raises(SessionStore::Error) { @store.create! }

      assert_equal "rooms_full", error.reason
      refute @cache.read(SessionStore::INDEX_KEY).key?("STALE")
    end

    test "prunes missing and expired entries before enforcing the active room limit" do
      expired_room = @store.create!
      @now = expired_room[:expires_at]
      index = {
        "MISSING" => (@now + 1.hour).iso8601(6),
        "EXPIRED" => (@now - 1.second).iso8601(6),
        expired_room[:code] => expired_room[:expires_at].iso8601(6)
      }
      @cache.write(SessionStore::INDEX_KEY, index, expires_in: 1.hour)

      100.times { @store.create! }
      error = assert_raises(SessionStore::Error) { @store.create! }

      assert_equal 503, error.close_code
      assert_equal "rooms_full", error.reason
      assert_equal 100, @cache.read(SessionStore::INDEX_KEY).length
      refute @cache.read(SessionStore::INDEX_KEY).key?("MISSING")
      refute @cache.read(SessionStore::INDEX_KEY).key?("EXPIRED")
      refute @cache.read(SessionStore::INDEX_KEY).key?(expired_room[:code])
    end

    test "joins normally and returns the last state" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "conn-1")
      @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "BASE64")

      result = @store.join!(code: created[:code], connection_id: "conn-2")

      assert_equal ["conn-1", "conn-2"], result[:participants]
      assert_equal({ version: 1, payload: "BASE64" }, result[:state])
      assert_equal created[:expires_at], result[:expires_at]
      assert_nil result[:replaced_connection_id]
    end

    test "claims and replaces creator status only with the creator secret" do
      created = @store.create!
      first = @store.join!(code: created[:code], connection_id: "creator-1", creator_secret: created[:creator_secret])
      replacement = @store.join!(code: created[:code], connection_id: "creator-2", creator_secret: created[:creator_secret])
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_equal ["creator-1"], first[:participants]
      assert_equal "creator-1", replacement[:replaced_connection_id]
      assert_equal ["creator-2"], replacement[:participants]
      assert_equal "creator-2", snapshot.fetch("creatorConnectionId")
      assert_nil snapshot.fetch("creatorGraceUntil")
    end

    test "rejects an invalid creator secret without revealing room state" do
      created = @store.create!

      error = assert_raises(SessionStore::Error) do
        @store.join!(code: created[:code], connection_id: "conn-1", creator_secret: "wrong-secret")
      end

      assert_equal 4401, error.close_code
      assert_equal "creator_secret_invalid", error.reason
      assert_empty @cache.read(snapshot_key(created[:code])).fetch("members")
    end

    test "rejects a supplied non-string creator secret" do
      created = @store.create!

      error = assert_raises(SessionStore::Error) do
        @store.join!(code: created[:code], connection_id: "conn-1", creator_secret: false)
      end

      assert_equal 4401, error.close_code
      assert_equal "creator_secret_invalid", error.reason
    end

    test "rejects unknown rooms and the ninth distinct participant" do
      unknown = assert_raises(SessionStore::Error) do
        @store.join!(code: "NOPE-123", connection_id: "conn-1")
      end
      assert_equal 4404, unknown.close_code

      created = @store.create!
      8.times { |index| @store.join!(code: created[:code], connection_id: "conn-#{index}") }

      full = assert_raises(SessionStore::Error) do
        @store.join!(code: created[:code], connection_id: "conn-9")
      end

      assert_equal 4409, full.close_code
      assert_equal "room_full", full.reason
    end

    test "rejects invalid room codes before cache or lock work" do
      invalid_codes = ["NOPE123", "NOPE-1234", "ILOO-234", "A" * 100_000]

      invalid_codes.each do |code|
        error = assert_raises(SessionStore::Error) do
          @store.join!(code: code, connection_id: "conn-1")
        end

        assert_equal 4404, error.close_code
        assert_equal "room_not_found", error.reason
      end

      assert_empty @lock_keys
      assert_empty @cache.writes
    end

    test "purges dead leases before checking room capacity" do
      created = @store.create!
      8.times { |index| @store.join!(code: created[:code], connection_id: "conn-#{index}") }
      @now += SessionStore::PRESENCE_LEASE

      result = @store.join!(code: created[:code], connection_id: "fresh")

      assert_equal ["fresh"], result[:participants]
    end

    test "returns stale member IDs when joining after a lease expires" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "stale")
      @now += SessionStore::PRESENCE_LEASE

      result = @store.join!(code: created[:code], connection_id: "fresh")

      assert_equal ["stale"], result[:removed_ids]
      assert_equal ["fresh"], result[:participants]
    end

    test "returns stale member IDs when recording a packet" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "sender")
      @store.join!(code: created[:code], connection_id: "stale")
      snapshot = @cache.read(snapshot_key(created[:code]))
      snapshot.fetch("members").fetch("stale")["lastSeen"] = (@now - SessionStore::PRESENCE_LEASE).iso8601(6)
      @cache.write(snapshot_key(created[:code]), snapshot, expires_in: SessionStore::ROOM_TTL)

      result = @store.record_packet!(code: created[:code], connection_id: "sender", payload: "PACKET")

      assert_equal ["stale"], result[:removed_ids]
      assert_equal 1, result[:version]
    end

    test "increments packet versions and replaces the latest payload" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "conn-1")

      assert_equal({ version: 1 }, @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "ONE"))
      assert_equal({ version: 2 }, @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "TWO"))
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_equal 2, snapshot.fetch("stateVersion")
      assert_equal "TWO", snapshot.fetch("lastPayload")
    end

    test "rejects packets from non-members and the eleventh packet in one second" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "conn-1")

      not_member = assert_raises(SessionStore::Error) do
        @store.record_packet!(code: created[:code], connection_id: "conn-2", payload: "NOPE")
      end
      assert_equal 4404, not_member.close_code

      10.times do |index|
        assert_equal({ version: index + 1 },
                     @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: index.to_s))
      end
      limited = assert_raises(SessionStore::Error) do
        @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "ELEVEN")
      end

      assert_equal 4429, limited.close_code
      assert_equal 10, @cache.read(snapshot_key(created[:code])).fetch("stateVersion")
      assert_equal "9", @cache.read(snapshot_key(created[:code])).fetch("lastPayload")
    end

    test "raises a distinct expiry error when joining an expired room" do
      created = @store.create!
      @now = created[:expires_at]

      error = assert_raises(SessionStore::ExpiredError) do
        @store.join!(code: created[:code], connection_id: "conn-1")
      end

      assert_equal 4404, error.close_code
      assert_equal "max_lifetime", error.reason
      assert_nil @cache.read(snapshot_key(created[:code]))
    end

    test "preserves max lifetime after the snapshot is physically evicted" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "conn-1")
      @cache.delete(snapshot_key(created[:code]))
      @now = created[:expires_at]

      result = @store.touch!(code: created[:code], connection_id: "conn-1")

      assert_equal "max_lifetime", result[:expired_reason]
      assert_nil @cache.read(expiry_marker_key(created[:code]))
      assert_nil @cache.read(SessionStore::INDEX_KEY)
    end

    test "reports max lifetime when joining after physical snapshot eviction" do
      created = @store.create!
      @cache.delete(snapshot_key(created[:code]))
      @now = created[:expires_at]

      error = assert_raises(SessionStore::ExpiredError) do
        @store.join!(code: created[:code], connection_id: "conn-1")
      end

      assert_equal "max_lifetime", error.reason
    end

    test "raises a distinct creator timeout error when recording a packet" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "creator", creator_secret: created[:creator_secret])
      @store.join!(code: created[:code], connection_id: "observer")
      @store.leave!(code: created[:code], connection_id: "creator")
      @now += SessionStore::CREATOR_GRACE

      error = assert_raises(SessionStore::ExpiredError) do
        @store.record_packet!(code: created[:code], connection_id: "observer", payload: "PAYLOAD")
      end

      assert_equal 4404, error.close_code
      assert_equal "creator_timeout", error.reason
      assert_nil @cache.read(snapshot_key(created[:code]))
    end

    test "starts a new rate window after one second" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "conn-1")
      10.times { @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "OLD") }

      @now += 1.second
      result = @store.record_packet!(code: created[:code], connection_id: "conn-1", payload: "NEW")

      assert_equal({ version: 11 }, result)
      assert_equal "NEW", @cache.read(snapshot_key(created[:code])).fetch("lastPayload")
    end

    test "touch renews the caller, removes dead members, and starts creator grace" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "creator", creator_secret: created[:creator_secret])
      @store.join!(code: created[:code], connection_id: "observer")
      @now += SessionStore::PRESENCE_LEASE

      result = @store.touch!(code: created[:code], connection_id: "observer")
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_equal ["creator"], result[:removed_ids]
      assert_nil result[:expired_reason]
      assert_equal (@now + SessionStore::CREATOR_GRACE).iso8601(6), snapshot.fetch("creatorGraceUntil")
    end

    test "expires after creator grace and prioritizes absolute lifetime" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "creator", creator_secret: created[:creator_secret])
      @store.join!(code: created[:code], connection_id: "observer")
      @store.leave!(code: created[:code], connection_id: "creator")
      @now += SessionStore::CREATOR_GRACE

      result = @store.touch!(code: created[:code], connection_id: "observer")
      assert_equal "creator_timeout", result[:expired_reason]
      assert_nil @cache.read(snapshot_key(created[:code]))
      assert_nil @cache.read(SessionStore::INDEX_KEY)

      second = @store.create!
      @store.join!(code: second[:code], connection_id: "conn-1")
      @now = second[:expires_at]
      result = @store.touch!(code: second[:code], connection_id: "conn-1")

      assert_equal "max_lifetime", result[:expired_reason]
      assert_nil @cache.read(snapshot_key(second[:code]))
    end

    test "prunes creator-grace-expired rooms from the active capacity index" do
      grace_room = @store.create!
      @store.join!(code: grace_room[:code], connection_id: "creator", creator_secret: grace_room[:creator_secret])
      @store.leave!(code: grace_room[:code], connection_id: "creator")
      99.times { @store.create! }
      @now += SessionStore::CREATOR_GRACE

      replacement = @store.create!

      refute_equal grace_room[:code], replacement[:code]
      refute @cache.read(SessionStore::INDEX_KEY).key?(grace_room[:code])
      assert_equal SessionStore::MAX_ACTIVE_ROOMS, @cache.read(SessionStore::INDEX_KEY).length
    end

    test "allows creator reconnection during grace and clears the grace deadline" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "creator-1", creator_secret: created[:creator_secret])
      @store.leave!(code: created[:code], connection_id: "creator-1")
      @now += 1.minute

      result = @store.join!(code: created[:code], connection_id: "creator-2", creator_secret: created[:creator_secret])
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_equal ["creator-2"], result[:participants]
      assert_nil result[:replaced_connection_id]
      assert_nil snapshot.fetch("creatorGraceUntil")
      assert_equal "creator-2", snapshot.fetch("creatorConnectionId")
    end

    test "leave is idempotent and only the recorded creator starts grace" do
      created = @store.create!
      @store.join!(code: created[:code], connection_id: "creator-1", creator_secret: created[:creator_secret])
      @store.join!(code: created[:code], connection_id: "creator-2", creator_secret: created[:creator_secret])

      old = @store.leave!(code: created[:code], connection_id: "creator-1")
      repeat = @store.leave!(code: created[:code], connection_id: "creator-1")
      current = @store.leave!(code: created[:code], connection_id: "creator-2")
      snapshot = @cache.read(snapshot_key(created[:code]))

      assert_equal false, old[:removed]
      assert_equal false, old[:creator_lost]
      assert_equal false, repeat[:removed]
      assert_equal true, current[:removed]
      assert_equal true, current[:creator_lost]
      assert_equal (@now + SessionStore::CREATOR_GRACE).iso8601(6), snapshot.fetch("creatorGraceUntil")
    end

    test "explicit expiration removes both snapshot and index" do
      created = @store.create!

      result = @store.expire!(code: created[:code], reason: "creator_timeout")

      assert_equal({ expired: true, reason: "creator_timeout" }, result)
      assert_nil @cache.read(snapshot_key(created[:code]))
      assert_nil @cache.read(SessionStore::INDEX_KEY)
      assert_equal({ expired: false, reason: "creator_timeout" },
                   @store.expire!(code: created[:code], reason: "creator_timeout"))
    end

    private

    def snapshot_key(code)
      "gwrank:rooms:v1:#{code}"
    end

    def expiry_marker_key(code)
      "gwrank:rooms:v1:expiry:#{code}"
    end
  end
end
