require "active_support/security_utils"
require "base64"
require "digest"
require "securerandom"
require "time"

module Rooms
  class SessionStore
    MAX_PARTICIPANTS = 8
    MAX_ACTIVE_ROOMS = 100
    ROOM_TTL = 2.hours
    CREATOR_GRACE = 5.minutes
    PRESENCE_LEASE = 90.seconds
    MESSAGES_PER_SECOND = 10

    CACHE_PREFIX = "gwrank:rooms:v1:"
    INDEX_KEY = "#{CACHE_PREFIX}index"
    LOCK_PREFIX = "gwrank:rooms:lock:v1:"
    INDEX_LOCK_KEY = "#{LOCK_PREFIX}index"
    CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

    class Error < StandardError
      attr_reader :close_code, :reason

      def initialize(close_code:, reason:)
        @close_code = close_code
        @reason = reason
        super(reason)
      end
    end

    class ExpiredError < Error; end

    def initialize(cache: Rails.cache, clock: -> { Time.current }, locker: nil)
      @cache = cache
      @clock = clock
      @locker = locker
    end

    def create!
      with_lock(INDEX_LOCK_KEY) do
        now = current_time
        index = prune_index(now)
        if index.length >= MAX_ACTIVE_ROOMS
          write_index(index, now)
          fail!(503, "rooms_full")
        end

        code = unique_code(index)
        creator_secret = Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false)
        expires_at = now + ROOM_TTL
        snapshot = {
          "creatorDigest" => Digest::SHA256.hexdigest(creator_secret),
          "createdAt" => timestamp(now),
          "expiresAt" => timestamp(expires_at),
          "creatorConnectionId" => nil,
          "creatorGraceUntil" => nil,
          "members" => {},
          "stateVersion" => 0,
          "lastPayload" => nil,
          "rateWindowStartedAt" => timestamp(now),
          "rateCount" => 0
        }

        write_snapshot(code, snapshot, now)
        index[code] = timestamp(expires_at)
        write_index(index, now)

        { code: code, creator_secret: creator_secret, expires_at: expires_at }
      end
    end

    def join!(code:, connection_id:, creator_secret: nil)
      code = normalize_code(code)
      connection_id = connection_id.to_s

      with_lock(room_lock_key(code)) do
        now = current_time
        snapshot = load_snapshot(code)
        fail!(4404, "room_not_found") unless snapshot
        expire_for_operation!(code, snapshot, now)

        creator_secret_provided = !creator_secret.nil?
        validate_creator_secret!(snapshot, creator_secret) if creator_secret_provided
        members = snapshot.fetch("members")
        purge_stale_members(snapshot, now)

        replaced_connection_id = replace_creator_member!(snapshot, connection_id) if creator_secret_provided
        unless members.key?(connection_id)
          fail!(4409, "room_full") if members.length >= MAX_PARTICIPANTS
          members[connection_id] = { "lastSeen" => timestamp(now) }
        else
          members.fetch(connection_id)["lastSeen"] = timestamp(now)
        end

        if creator_secret_provided
          snapshot["creatorConnectionId"] = connection_id
          snapshot["creatorGraceUntil"] = nil
        end

        write_snapshot(code, snapshot, now)
        {
          participants: members.keys,
          state: last_state(snapshot),
          expires_at: parse_time(snapshot.fetch("expiresAt")),
          replaced_connection_id: replaced_connection_id
        }
      end
    end

    def record_packet!(code:, connection_id:, payload:)
      code = normalize_code(code)
      connection_id = connection_id.to_s

      with_lock(room_lock_key(code)) do
        now = current_time
        snapshot = load_snapshot(code)
        fail!(4404, "room_not_found") unless snapshot
        expire_for_operation!(code, snapshot, now)
        purge_stale_members(snapshot, now)
        fail!(4404, "room_not_found") unless snapshot.fetch("members").key?(connection_id)

        rate_window_started_at = parse_time(snapshot.fetch("rateWindowStartedAt"))
        if now - rate_window_started_at >= 1.second
          snapshot["rateWindowStartedAt"] = timestamp(now)
          snapshot["rateCount"] = 0
        end
        fail!(4429, "rate_limited") if snapshot.fetch("rateCount") >= MESSAGES_PER_SECOND

        snapshot["rateCount"] += 1
        snapshot["stateVersion"] += 1
        snapshot["lastPayload"] = payload
        write_snapshot(code, snapshot, now)

        { version: snapshot.fetch("stateVersion") }
      end
    end

    def touch!(code:, connection_id:)
      code = normalize_code(code)
      connection_id = connection_id.to_s

      with_lock(room_lock_key(code)) do
        now = current_time
        snapshot = load_snapshot(code)
        fail!(4404, "room_not_found") unless snapshot
        expired_reason = expire_for_operation!(code, snapshot, now, return_reason: true)
        next({ removed_ids: [], expired_reason: expired_reason }) if expired_reason

        members = snapshot.fetch("members")
        fail!(4404, "room_not_found") unless members.key?(connection_id)
        members.fetch(connection_id)["lastSeen"] = timestamp(now)

        removed_ids = remove_stale_members(snapshot, now, except: connection_id)
        creator_connection_id = snapshot["creatorConnectionId"]
        if creator_connection_id && !members.key?(creator_connection_id)
          snapshot["creatorConnectionId"] = nil
          snapshot["creatorGraceUntil"] ||= timestamp(now + CREATOR_GRACE)
        end

        write_snapshot(code, snapshot, now)
        { removed_ids: removed_ids, expired_reason: nil }
      end
    end

    def leave!(code:, connection_id:)
      code = normalize_code(code)
      connection_id = connection_id.to_s

      with_lock(room_lock_key(code)) do
        now = current_time
        snapshot = load_snapshot(code)
        unless snapshot
          next({ removed: false, creator_lost: false, expired_reason: nil })
        end

        expired_reason = expire_for_operation!(code, snapshot, now, return_reason: true)
        if expired_reason
          next({
            removed: snapshot.fetch("members").key?(connection_id),
            creator_lost: snapshot["creatorConnectionId"] == connection_id,
            expired_reason: expired_reason
          })
        end

        members = snapshot.fetch("members")
        removed = members.delete(connection_id)
        creator_lost = removed && snapshot["creatorConnectionId"] == connection_id
        if creator_lost
          snapshot["creatorConnectionId"] = nil
          snapshot["creatorGraceUntil"] = timestamp(now + CREATOR_GRACE)
        end

        write_snapshot(code, snapshot, now) if removed
        { removed: !removed.nil?, creator_lost: !!creator_lost, expired_reason: nil }
      end
    end

    def expire!(code:, reason:)
      code = normalize_code(code)

      with_lock(room_lock_key(code)) do
        snapshot = load_snapshot(code)
        if snapshot
          delete_snapshot_and_index(code)
          { expired: true, reason: reason }
        else
          remove_from_index(code)
          { expired: false, reason: reason }
        end
      end
    end

    private

    def current_time
      @clock.call
    end

    def normalize_code(code)
      code.to_s.upcase
    end

    def snapshot_key(code)
      "#{CACHE_PREFIX}#{code}"
    end

    def room_lock_key(code)
      "#{LOCK_PREFIX}#{code}"
    end

    def unique_code(index)
      loop do
        code = Array.new(7) { CODE_ALPHABET[SecureRandom.random_number(CODE_ALPHABET.length)] }.join
        code = "#{code[0, 4]}-#{code[4, 3]}"
        return code unless index.key?(code) || @cache.read(snapshot_key(code))
      end
    end

    def with_lock(key)
      if @locker
        @locker.call(key) { yield }
      else
        with_advisory_lock(key) { yield }
      end
    end

    def with_advisory_lock(key)
      ActiveRecord::Base.transaction do
        connection = ActiveRecord::Base.connection
        connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote(key)}))")
        yield
      end
    end

    def load_snapshot(code)
      @cache.read(snapshot_key(code))
    end

    def write_snapshot(code, snapshot, now)
      expires_at = parse_time(snapshot.fetch("expiresAt"))
      remaining = expires_at - now
      @cache.write(snapshot_key(code), snapshot, expires_in: remaining) if remaining.positive?
    end

    def write_index(index, now)
      if index.empty?
        @cache.delete(INDEX_KEY)
      else
        expires_at = index.values.map { |value| parse_time(value) }.max
        remaining = expires_at - now
        if remaining.positive?
          @cache.write(INDEX_KEY, index, expires_in: remaining)
        else
          @cache.delete(INDEX_KEY)
        end
      end
    end

    def prune_index(now)
      raw_index = @cache.read(INDEX_KEY)
      return {} unless raw_index.is_a?(Hash)

      raw_index.each_with_object({}) do |(code, indexed_expiry), index|
        code = normalize_code(code)
        snapshot = load_snapshot(code)
        next unless snapshot
        next if parse_time(indexed_expiry) <= now
        next if parse_time(snapshot.fetch("expiresAt")) <= now

        index[code] = indexed_expiry
      end
    end

    def remove_from_index(code)
      with_lock(INDEX_LOCK_KEY) do
        now = current_time
        index = prune_index(now)
        index.delete(code)
        write_index(index, now)
      end
    end

    def delete_snapshot_and_index(code)
      @cache.delete(snapshot_key(code))
      remove_from_index(code)
    end

    def parse_time(value)
      value.is_a?(String) ? Time.iso8601(value) : value.to_time
    end

    def timestamp(value)
      value.iso8601(6)
    end

    def fail!(close_code, reason)
      raise Error.new(close_code: close_code, reason: reason)
    end

    def validate_creator_secret!(snapshot, creator_secret)
      unless creator_secret.is_a?(String)
        fail!(4401, "creator_secret_invalid")
      end

      digest = Digest::SHA256.hexdigest(creator_secret)
      valid = ActiveSupport::SecurityUtils.secure_compare(snapshot.fetch("creatorDigest"), digest)
      fail!(4401, "creator_secret_invalid") unless valid
    end

    def expire_for_operation!(code, snapshot, now, return_reason: false)
      reason = expiration_reason(snapshot, now)
      return nil unless reason

      delete_snapshot_and_index(code)
      return reason if return_reason

      raise ExpiredError.new(close_code: 4404, reason: reason)
    end

    def expiration_reason(snapshot, now)
      return "max_lifetime" if now >= parse_time(snapshot.fetch("expiresAt"))

      grace_until = snapshot["creatorGraceUntil"]
      return "creator_timeout" if grace_until && now >= parse_time(grace_until)

      nil
    end

    def purge_stale_members(snapshot, now)
      remove_stale_members(snapshot, now)
      creator_connection_id = snapshot["creatorConnectionId"]
      if creator_connection_id && !snapshot.fetch("members").key?(creator_connection_id)
        snapshot["creatorConnectionId"] = nil
        snapshot["creatorGraceUntil"] ||= timestamp(now + CREATOR_GRACE)
      end
    end

    def remove_stale_members(snapshot, now, except: nil)
      threshold = now - PRESENCE_LEASE
      members = snapshot.fetch("members")
      removed_ids = []
      members.delete_if do |connection_id, member|
        next false if connection_id == except

        stale = parse_time(member.fetch("lastSeen")) <= threshold
        removed_ids << connection_id if stale
        stale
      end
      removed_ids
    end

    def replace_creator_member!(snapshot, connection_id)
      current_creator = snapshot["creatorConnectionId"]
      return nil unless current_creator && current_creator != connection_id
      return nil unless snapshot.fetch("members").delete(current_creator)

      current_creator
    end

    def last_state(snapshot)
      return nil unless snapshot["lastPayload"]

      { version: snapshot.fetch("stateVersion"), payload: snapshot.fetch("lastPayload") }
    end
  end
end
