require "test_helper"
require "solid_cache"

module Rooms
  class SessionStoreConcurrencyTest < ActiveSupport::TestCase
    class TrackingCache
      def initialize(cache)
        @cache = cache
        @keys = []
        @mutex = Mutex.new
      end

      def read(name)
        @cache.read(name)
      end

      def write(name, value, options = nil)
        @mutex.synchronize { @keys << name unless @keys.include?(name) }
        @cache.write(name, value, options)
      end

      def delete(name)
        @mutex.synchronize { @keys << name unless @keys.include?(name) }
        @cache.delete(name)
      end

      def cleanup!
        keys = @mutex.synchronize { @keys.dup }
        keys.each { |key| @cache.delete(key) }
      end
    end

    setup do
      @namespace = "gwrank-task-8-#{SecureRandom.hex(8)}"
      @cache = TrackingCache.new(SolidCache::Store.new(namespace: @namespace))
      @stores = 2.times.map { SessionStore.new(cache: @cache) }
      @room = with_database_connection { @stores.first.create! }
    end

    teardown do
      with_database_connection { @cache.cleanup! } if @cache
    end

    test "serializes concurrent admissions at the eight participant limit" do
      member_ids = [
        %w[member-0 member-1 member-2 member-3],
        %w[member-4 member-5 member-6 member-7]
      ]

      results = run_two_threads do |store, index, barrier|
        thread_results = member_ids.fetch(index).map do |connection_id|
          barrier.wait
          begin
            store.join!(code: @room[:code], connection_id: connection_id)
          rescue SessionStore::Error => error
            error
          end
        end
        if index.zero?
          begin
            thread_results << store.join!(code: @room[:code], connection_id: "member-8")
          rescue SessionStore::Error => error
            thread_results << error
          end
        end
        thread_results
      end.flatten

      successful = results.grep(Hash)
      rejected = results.grep(SessionStore::Error)
      snapshot = @cache.read(snapshot_key(@room[:code]))

      assert_equal 8, successful.length
      assert_equal 1, rejected.length
      assert_equal 4409, rejected.first.close_code
      assert_equal "room_full", rejected.first.reason
      assert_equal 8, snapshot.fetch("members").length
    end

    test "preserves every concurrent packet version in shared cache" do
      with_database_connection do
        @stores.first.join!(code: @room[:code], connection_id: "sender-0")
        @stores.first.join!(code: @room[:code], connection_id: "sender-1")
      end

      results = run_two_threads do |store, index, barrier|
        4.times.map do |packet_index|
          barrier.wait
          store.record_packet!(
            code: @room[:code],
            connection_id: "sender-#{index}",
            payload: "packet-#{index}-#{packet_index}"
          )
        end
      end.flatten
      snapshot = @cache.read(snapshot_key(@room[:code]))
      accepted_payloads = 2.times.flat_map do |index|
        4.times.map { |packet_index| "packet-#{index}-#{packet_index}" }
      end

      assert_equal 8, results.length
      assert_equal (1..8).to_a, results.map { |result| result.fetch(:version) }.sort
      assert_equal 8, snapshot.fetch("stateVersion")
      assert_includes accepted_payloads, snapshot.fetch("lastPayload")
    end

    test "keeps a replacement creator after a concurrent stale leave" do
      with_database_connection do
        @stores.first.join!(
          code: @room[:code],
          connection_id: "creator-old",
          creator_secret: @room[:creator_secret]
        )
      end

      results = run_two_threads do |store, index, barrier|
        barrier.wait
        if index.zero?
          store.leave!(code: @room[:code], connection_id: "creator-old")
        else
          store.join!(
            code: @room[:code],
            connection_id: "creator-new",
            creator_secret: @room[:creator_secret]
          )
        end
      end
      snapshot = @cache.read(snapshot_key(@room[:code]))

      assert results.first.key?(:removed)
      assert_includes results.second.fetch(:participants), "creator-new"
      assert_equal "creator-new", snapshot.fetch("creatorConnectionId")
      assert_nil snapshot.fetch("creatorGraceUntil")
      assert snapshot.fetch("members").key?("creator-new")
    end

    private

    def with_database_connection
      ActiveRecord::Base.connection_pool.with_connection { yield }
    end

    def run_two_threads
      barrier = Concurrent::CyclicBarrier.new(2)
      threads = @stores.each_with_index.map do |store, index|
        Thread.new do
          with_database_connection { yield(store, index, barrier) }
        end
      end

      threads.map(&:value)
    end

    def snapshot_key(code)
      "gwrank:rooms:v1:#{code}"
    end
  end
end
