require "test_helper"

class ZCodex::LatestReleaseTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "resolves version and installer URL from the GitHub payload" do
    with_http(github_payload) do |service|
      release = service.call

      assert_equal "1.2.3", release.version
      assert_equal "https://github.com/LuxIudicium/Z-Codex/releases/download/v1.2.3/Z-Codex-1.2.3-setup.exe",
                   release.asset_url
    end
  end

  test "returns nil when no setup.exe asset is attached" do
    payload = github_payload(assets: [
      { "name" => "source.zip", "browser_download_url" => "https://example.com/source.zip" }
    ])

    with_http(payload) do |service|
      assert_nil service.call
    end
  end

  test "ignores assets whose name merely contains setup.exe" do
    payload = github_payload(assets: [
      { "name" => "Z-Codex-1.2.3-mysetup.exe", "browser_download_url" => "https://example.com/wrong.exe" },
      { "name" => "Z-Codex-1.2.3-setup.exe",
        "browser_download_url" => "https://github.com/LuxIudicium/Z-Codex/releases/download/v1.2.3/Z-Codex-1.2.3-setup.exe" }
    ])

    with_http(payload) do |service|
      assert_equal "https://github.com/LuxIudicium/Z-Codex/releases/download/v1.2.3/Z-Codex-1.2.3-setup.exe",
                   service.call.asset_url
    end
  end

  test "returns nil when GitHub is unreachable" do
    service = ZCodex::LatestRelease.new
    service.stub(:http_get, -> { raise Errno::ECONNREFUSED }) do
      assert_nil service.call
    end
  end

  test "caches a successful resolution" do
    calls = 0
    fetcher = -> { calls += 1; github_payload }

    service = ZCodex::LatestRelease.new
    service.stub(:http_get, fetcher) do
      service.call
      service.call
    end

    assert_equal 1, calls
  end

  test "negatively caches failures for later retries" do
    calls = 0
    fetcher = -> { calls += 1; raise Errno::ECONNREFUSED }

    service = ZCodex::LatestRelease.new
    service.stub(:http_get, fetcher) do
      2.times { service.call }
    end

    assert_equal 1, calls
    assert_equal false, Rails.cache.read(ZCodex::LatestRelease::CACHE_KEY)
  end

  private

  def with_http(payload)
    service = ZCodex::LatestRelease.new
    service.stub(:http_get, payload) { yield service }
  end

  def github_payload(assets: nil)
    {
      "tag_name" => "v1.2.3",
      "assets" => assets || [
        {
          "name" => "Z-Codex-1.2.3-setup.exe",
          "browser_download_url" => "https://github.com/LuxIudicium/Z-Codex/releases/download/v1.2.3/Z-Codex-1.2.3-setup.exe"
        },
        {
          "name" => "source.zip",
          "browser_download_url" => "https://example.com/source.zip"
        }
      ]
    }
  end
end
