require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "GET /z-codex renders successfully" do
    ZCodex::LatestRelease.stub(:call, nil) do
      get z_codex_path
    end

    assert_response :success
  end

  test "GET /z-codex/download redirects to the installer asset" do
    release = ZCodex::LatestRelease::Release.new(
      version: "1.2.3",
      asset_url: "https://github.com/LuxIudicium/Z-Codex/releases/download/v1.2.3/Z-Codex-1.2.3-setup.exe"
    )

    ZCodex::LatestRelease.stub(:call, release) do
      get z_codex_download_path
    end

    assert_redirected_to release.asset_url
  end

  test "GET /z-codex/download falls back to the GitHub releases page" do
    ZCodex::LatestRelease.stub(:call, nil) do
      get z_codex_download_path
    end

    assert_redirected_to ZCodex::LatestRelease::RELEASES_PAGE_URL
  end
end
