# frozen_string_literal: true

require "net/http"
require "json"

module ZCodex
  class LatestRelease
    Release = Data.define(:version, :asset_url)

    CACHE_KEY = "zcodex/latest-release"
    CACHE_TTL = 1.hour
    NEGATIVE_TTL = 5.minutes
    TIMEOUT = 3
    API_URL = "https://api.github.com/repos/LuxIudicium/Z-Codex/releases/latest"
    RELEASES_PAGE_URL = "https://github.com/LuxIudicium/Z-Codex/releases/latest"

    class << self
      def call
        new.call
      end
    end

    def call
      cached = Rails.cache.read(CACHE_KEY)
      return nil if cached == false
      return cached if cached.is_a?(Release)

      release = fetch_release
      Rails.cache.write(CACHE_KEY, release || false, expires_in: release ? CACHE_TTL : NEGATIVE_TTL)
      release
    end

    private

    def fetch_release
      payload = http_get
      build_release(payload)
    rescue StandardError => e
      Rails.logger.warn("[ZCodex::LatestRelease] #{e.class}: #{e.message}")
      nil
    end

    def http_get
      uri = URI(API_URL)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["User-Agent"] = "GWRank (+https://gwrank.com)"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(request)
      end

      raise "GitHub API responded with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def build_release(payload)
      asset = payload["assets"]&.find { |candidate| candidate["name"].match?(/setup\.exe\z/i) }

      Release.new(
        version: payload["tag_name"].to_s.sub(/\Av/i, ""),
        asset_url: asset["browser_download_url"]
      ) if asset
    end
  end
end
