class StaticPagesController < ApplicationController
  def terms
  end

  def privacy
  end

  def z_codex
    @latest_release = ZCodex::LatestRelease.call
  end

  def download
    release = ZCodex::LatestRelease.call
    redirect_to release ? release.asset_url : ZCodex::LatestRelease::RELEASES_PAGE_URL,
                allow_other_host: true
  end
end
