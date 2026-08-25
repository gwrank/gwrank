require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "GET /z-codex renders the landing page with a versioned download button" do
    release = ZCodex::LatestRelease::Release.new(
      version: "1.2.3",
      asset_url: "https://github.com/LuxIudicium/Z-Codex/releases/download/v1.2.3/Z-Codex-1.2.3-setup.exe"
    )

    ZCodex::LatestRelease.stub(:call, release) do
      get z_codex_path
    end

    assert_response :success
    assert_select 'body', text: /Team build manager for Guild Wars 1/
    assert_select "a[href='#{z_codex_download_path}']", text: /Download Z-Codex v1\.2\.3/
    assert_select "td code", text: '.zcx'
    assert_select 'body', text: /First launch/
    assert_select 'body', text: /100% compatible with your paw\*ned² builds and teambuilds!/
  end

  test "GET /z-codex shows a generic button pointing at GitHub when the release is unknown" do
    ZCodex::LatestRelease.stub(:call, nil) do
      get z_codex_path
    end

    assert_response :success
    assert_select "a[href='#{ZCodex::LatestRelease::RELEASES_PAGE_URL}']", text: 'Download Z-Codex'
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
