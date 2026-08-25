# Z-Codex Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `/z-codex` landing page on GWRank.com describing Z-Codex and offering a working download button, linked from the homepage's "Z-Codex Compatible" section.

**Architecture:** Extend `StaticPagesController` (same pattern as `terms`/`privacy`) with two actions: `z_codex` renders the page, `download` 302-redirects to the newest `setup.exe` asset resolved from the GitHub Releases API by a small PORO service (`ZCodex::LatestRelease`) with positive caching (1h) and negative caching (5min). Any GitHub failure degrades to a redirect to the public releases page.

**Tech Stack:** Rails 8, Net::HTTP stdlib (no new gems), Rails.cache, Tailwind v4 GW component classes, Minitest.

**Spec:** `docs/superpowers/specs/2026-08-25-z-codex-landing-page-design.md`

**Deviation from spec:** The spec says RSpec; this repo's convention for controller/page/service tests is **Minitest** (`test/controllers/`, `test/services/`) — RSpec/rswag covers only the JSON API. Plan follows repo convention.

---

### Task 1: `ZCodex::LatestRelease` service

Resolves the newest non-draft/non-prerelease release of `LuxIudium/Z-Codex` from the GitHub API and picks its `*-setup.exe` asset. Cached; never raises.

**Files:**
- Create: `app/services/z_codex/latest_release.rb`
- Test: `test/services/z_codex/latest_release_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/services/z_codex/latest_release_test.rb`:

```ruby
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
```

Notes for the implementer:
- `Object#stub` comes from ActiveSupport and patches private instance methods within the block — that's how the HTTP boundary is mocked without WebMock.
- `false` is the sentinel written to cache on failure (distinguishes "known bad, retry after TTL" from a cache miss).
- Swapping `Rails.cache` to a memory store isolates caching tests from the null store used in the test env.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/z_codex/latest_release_test.rb`
Expected: FAIL — `NameError: uninitialized constant ZCodex` (or similar load error).

- [ ] **Step 3: Write the implementation**

Create `app/services/z_codex/latest_release.rb`:

```ruby
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
```

Implementation notes:
- `GET /releases/latest` already excludes drafts and prereleases.
- `User-Agent` is mandatory for GitHub API requests; omitting it yields 403.
- Timeouts are deliberately short (3s) so an upstream outage cannot stall workers.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/z_codex/latest_release_test.rb`
Expected: 5 runs, 0 failures, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add app/services/z_codex/latest_release.rb test/services/z_codex/latest_release_test.rb
git commit -m "feat(z-codex): resolve latest release from GitHub API"
```

---

### Task 2: Routes and controller actions

Adds `/z-codex` and `/z-codex/download`. The page renders (minimal placeholder view for now); the download action always answers with a redirect.

**Files:**
- Modify: `config/routes.rb:53-55`
- Modify: `app/controllers/static_pages_controller.rb`
- Create: `app/views/static_pages/z_codex.html.erb` (placeholder, replaced in Task 3)
- Test: `test/controllers/static_pages_controller_test.rb` (new file)

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/static_pages_controller_test.rb`:

```ruby
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/static_pages_controller_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'z_codex_path'` (route missing).

- [ ] **Step 3: Add the routes**

In `config/routes.rb`, change:

```ruby
  get 'privacy', to: 'static_pages#privacy'
  get 'terms', to: 'static_pages#terms'
```

to:

```ruby
  get 'privacy', to: 'static_pages#privacy'
  get 'terms', to: 'static_pages#terms'
  get 'z-codex', to: 'static_pages#z_codex'
  get 'z-codex/download', to: 'static_pages#download'
```

This defines helpers `z_codex_path` and `z_codex_download_path`.

- [ ] **Step 4: Add the controller actions**

Rewrite `app/controllers/static_pages_controller.rb`:

```ruby
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
```

`allow_other_host: true` is required on Rails 7.1+ / 8 for cross-origin `redirect_to` (otherwise it raises `UnsafeRedirectError`).

- [ ] **Step 5: Create the placeholder view**

Create `app/views/static_pages/z_codex.html.erb`:

```erb
<div class="gw-window gw-frame p-6">Z-Codex</div>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/controllers/static_pages_controller_test.rb`
Expected: 3 runs, 0 failures, 0 errors.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/static_pages_controller.rb app/views/static_pages/z_codex.html.erb test/controllers/static_pages_controller_test.rb
git commit -m "feat(z-codex): landing page route and download redirect"
```

---

### Task 3: Landing page content

Replaces the placeholder with the full product page using the existing GW component vocabulary (`gw-window`, `gw-frame`, `gw-btn`, Tailwind tokens like `text-gold-300`, `text-muted`, `font-display`). Hardcoded English copy, consistent with every other view.

**Files:**
- Modify: `app/views/static_pages/z_codex.html.erb` (full rewrite)
- Test: `test/controllers/static_pages_controller_test.rb` (extend first test)

- [ ] **Step 1: Extend the failing test**

In `test/controllers/static_pages_controller_test.rb`, replace:

```ruby
  test "GET /z-codex renders successfully" do
    ZCodex::LatestRelease.stub(:call, nil) do
      get z_codex_path
    end

    assert_response :success
  end
```

with:

```ruby
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
    assert_select "a[href='/z-codex/download']", text: /Download Z-Codex v1\.2\.3/
    assert_select "td code", text: '.zcx'
    assert_select 'body', text: /First launch/
  end

  test "GET /z-codex shows a generic button pointing at GitHub when the release is unknown" do
    ZCodex::LatestRelease.stub(:call, nil) do
      get z_codex_path
    end

    assert_response :success
    assert_select "a[href='#{ZCodex::LatestRelease::RELEASES_PAGE_URL}']", text: 'Download Z-Codex'
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/static_pages_controller_test.rb`
Expected: FAIL — the placeholder view lacks the asserted content (first test fails on the tagline assertion).

- [ ] **Step 3: Write the full landing page**

Replace the entire content of `app/views/static_pages/z_codex.html.erb` with:

```erb
<div class="space-y-6">
  <section class="gw-window gw-frame">
    <div class="text-center px-6 py-10 sm:py-14 space-y-4">
      <h1 class="font-display text-gold-300 text-4xl tracking-[0.35em] m-0">Z-CODEX</h1>
      <p class="italic text-lg text-muted max-w-xl mx-auto m-0">
        Team build manager for Guild Wars 1 — spiritual successor to paw*ned².
        Compose your team, simulate its mechanics, exchange builds in game-ready formats.
      </p>
      <p class="font-display text-gold-500 text-xs tracking-widest uppercase space-x-2">
        <span>Free</span><span>·</span><span>Open source (MIT)</span><span>·</span><span>Unofficial tool</span>
      </p>
      <div class="flex flex-wrap justify-center items-center gap-3 pt-2">
        <% if @latest_release %>
          <%= link_to "Download Z-Codex v#{@latest_release.version}", z_codex_download_path, class: 'gw-btn' %>
          <span class="text-sm text-muted">Windows 10/11 · 64-bit · ~50 MB installer</span>
        <% else %>
          <%= link_to "Download Z-Codex", ZCodex::LatestRelease::RELEASES_PAGE_URL,
                      target: '_blank', rel: 'noopener noreferrer', class: 'gw-btn' %>
          <span class="text-sm text-muted">Windows 10/11 · 64-bit · ~50 MB installer · hosted on GitHub</span>
        <% end %>
        <%= link_to 'Source & issues on GitHub', 'https://github.com/LuxIudicium/Z-Codex',
                    target: '_blank', rel: 'noopener noreferrer', class: 'gw-btn gw-btn--ghost' %>
      </div>
    </div>
  </section>

  <section class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">🛡️ Team Composition</h3>
      <p class="text-muted text-sm m-0">
        Eight characters × eight skills, primary and secondary professions, attributes. Build variants organized
        in trees and locked together. A filterable catalog of every skill with detailed tooltips.
      </p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">⚔️ Combat Simulation</h3>
      <p class="text-muted text-sm m-0">
        Spike damage with cast order and life steal, damage per armor level, an armor calculator, energy
        management and the ten conditions of the monthly flux cycle.
      </p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">📦 Community Builds</h3>
      <p class="text-muted text-sm m-0">
        Fetches ~1,460 builds and ~250 teams from the PvXwiki build packs, dropped wherever you want, in the
        very format Guild Wars reads itself.
      </p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">✨ Comfort</h3>
      <p class="text-muted text-sm m-0">
        French and English UI switchable on the fly, light and dark themes, three icon sizes, copy-paste ready
        build screenshots, undo/redo and a file browser.
      </p>
    </div>
  </section>

  <section class="grid gap-4 lg:grid-cols-2">
    <div class="gw-doc gw-window gw-frame p-5 sm:p-6">
      <h3 class="mt-0">Game-ready file formats</h3>
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left">
            <th class="py-1 pr-3">Extension</th>
            <th class="py-1 pr-3">Role</th>
            <th class="py-1">Access</th>
          </tr>
        </thead>
        <tbody class="text-muted">
          <tr>
            <td class="py-1 pr-3"><code>.zcx</code></td>
            <td class="py-1 pr-3">Native format — full team, equipment, settings</td>
            <td class="py-1">read / write</td>
          </tr>
          <tr>
            <td class="py-1 pr-3"><code>.pn3</code></td>
            <td class="py-1 pr-3">Previous native format</td>
            <td class="py-1">read / write</td>
          </tr>
          <tr>
            <td class="py-1 pr-3"><code>.pwnd</code></td>
            <td class="py-1 pr-3">paw*ned² files</td>
            <td class="py-1">read / write</td>
          </tr>
          <tr>
            <td class="py-1 pr-3"><code>.txt</code></td>
            <td class="py-1 pr-3">Game template codes (<code>O…</code> skills, <code>P…</code> equipment)</td>
            <td class="py-1">read / write</td>
          </tr>
        </tbody>
      </table>
      <p class="text-sm text-muted mb-0">
        Template codes copy-paste straight from and into Guild Wars — the same codes GWRank serves through its
        <%= link_to 'build library', builds_path %> and REST API.
      </p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 sm:p-6">
      <h3 class="mt-0">First launch</h3>
      <p>
        An internet connection is required once: Z-Codex downloads its skill catalog (~8 MB, about five minutes)
        directly from the public Guild Wars Wiki, at a deliberately throttled pace to stay gentle on the wiki.
      </p>
      <p class="mb-0">
        After that one-time fetch, the app starts in seconds and runs fully offline. When the game updates,
        Z-Codex detects it and offers to refresh its catalog.
      </p>
    </div>
  </section>

  <p class="text-center text-xs text-muted m-0">
    Z-Codex is MIT-licensed software by P. Vincent —
    <%= link_to 'source on GitHub', 'https://github.com/LuxIudicium/Z-Codex',
                target: '_blank', rel: 'noopener noreferrer' %>.
    Not affiliated with ArenaNet or NCSOFT; no game assets are redistributed with the software.
    Guild Wars is a trademark of ArenaNet, LLC and NCSOFT Corporation.
  </p>
</div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/static_pages_controller_test.rb`
Expected: 4 runs, 0 failures, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add app/views/static_pages/z_codex.html.erb test/controllers/static_pages_controller_test.rb
git commit -m "feat(z-codex): landing page content"
```

---

### Task 4: Homepage wiring

Turns the passive "Z-Codex Compatible" badge into a link to the landing page and adds a "Get Z-Codex →" link inside the Build Library card.

**Files:**
- Modify: `app/views/home/index.html.erb:17,28-31`
- Test: `test/controllers/home_controller_test.rb:4-16`

- [ ] **Step 1: Extend the failing test**

In `test/controllers/home_controller_test.rb`, inside the test `"renders the showcase homepage"`, after:

```ruby
    assert_select 'body', text: /Documentation/
```

add:

```ruby
    assert_select "a[href='/z-codex']", text: 'Z-Codex Compatible'
    assert_select "a[href='/z-codex']", text: /Get Z-Codex/
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: FAIL — badge is currently a `<span>`, not a link (first new assertion fails).

- [ ] **Step 3: Make the badge a link and add the CTA**

In `app/views/home/index.html.erb`, change line 17:

```erb
      <span class="font-display text-gold-500 text-xs tracking-widest uppercase">Z-Codex Compatible</span>
```

to:

```erb
      <%= link_to 'Z-Codex Compatible', z_codex_path, class: 'font-display text-gold-500 text-xs tracking-widest uppercase hover:text-gold-300' %>
```

and change the card's links paragraph:

```erb
      <p class="mt-auto m-0 space-x-4">
        <%= link_to 'Browse the library →', builds_path %>
        <%= link_to 'API documentation', '/api-docs' %>
      </p>
```

to:

```erb
      <p class="mt-auto m-0 space-x-4">
        <%= link_to 'Browse the library →', builds_path %>
        <%= link_to 'API documentation', '/api-docs' %>
        <%= link_to 'Get Z-Codex →', z_codex_path %>
      </p>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: 2 runs, 0 failures, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add app/views/home/index.html.erb test/controllers/home_controller_test.rb
git commit -m "feat(home): wire showcase card to Z-Codex page"
```

---

### Task 5: Full verification

- [ ] **Step 1: Run the entire test suite**

Run: `bin/rails test`
Expected: all tests pass, including the nine new ones (5 service + 4 static pages; the home test gains assertions).

- [ ] **Step 2: Smoke-check the real GitHub round-trip**

Run: `bin/rails server -d && sleep 3 && curl -sI http://localhost:3000/z-codex/download | head -5; kill %1 2>/dev/null`

Expected behavior:
- If the repo has at least one published release: `HTTP/1.1 302 Found` with `Location:` pointing at a `.exe` asset on `github.com`.
- If the repo has **no releases yet** (state observed on 2026-08-25): GitHub answers 404, the service logs `[ZCodex::LatestRelease] …` at warn level and the route still answers `302 Found` → `Location: https://github.com/LuxIudicium/Z-Codex/releases/latest`.

Also visit `http://localhost:3000/z-codex` and `http://localhost:3000/` in a browser to eyeball layout consistency with the rest of the site.

- [ ] **Step 3: No uncommitted leftovers**

Run: `git status --short`
Expected: nothing related to this feature pending (pre-existing untracked files `bin/annotaterb`, `data/teambuild_example.zcx` are out of scope).
