# Z-Codex Landing Page — Design

**Date:** 2026-08-25
**Status:** Approved

## Goal

Give [Z-Codex](https://github.com/LuxIudicium/Z-Codex) a landing page on GWRank.com where visitors can download the Windows installer. The page is reached from the homepage's existing "Z-Codex Compatible" section.

Z-Codex is a free, open-source (MIT) team build manager for Guild Wars 1 by P. Vincent — successor to paw\*ned². It ships exclusively via GitHub Releases as `Z-Codex-<version>-setup.exe` (~50 MB, Windows 10/11 64-bit).

## Decisions

| Question | Decision |
|---|---|
| Download mechanism | **Smart redirect**: Rails resolves the newest release asset via GitHub API (cached) and 302-redirects to the `.exe`. Falls back to the GitHub releases page. |
| Homepage entry | **Wire up the existing section**: the "Z-Codex Compatible" badge becomes a link; add a "Get Z-Codex →" line inside the Build Library card. No new grid cards. |
| Content scope | **Standard product page**: hero + download + features + file formats + first-launch note + legal line. No screenshots/FAQ/FR translation. |
| Implementation | **Extend `StaticPagesController`** (matches `terms`/`privacy` pattern) with one small service object. No new dependencies. |

## Routes

```ruby
get 'z-codex',          to: 'static_pages#z_codex'
get 'z-codex/download', to: 'static_pages#download'
```

Helpers: `z_codex_path`, `z_codex_download_path`.

## Service: `ZCodex::LatestRelease`

Location: `app/services/z_codex/latest_release.rb`.

- `.call` returns a value object (`Data.define(:version, :asset_url)`) or `nil`.
- Cache first: `Rails.cache`, key `"zcodex/latest-release"`, TTL **1 hour**.
- On miss: `GET https://api.github.com/repos/LuxIudicium/Z-Codex/releases/latest`
  - Headers: `Accept: application/vnd.github+json`, `User-Agent` set (GitHub requires it).
  - Timeouts: 3s open / 3s read.
  - `/releases/latest` already excludes drafts and prereleases.
  - Asset selection: name matches `/setup\.exe\z/i`; take `browser_download_url`.
  - `version` = tag name with leading `v` stripped.
- Any failure (HTTP error, timeout, JSON malformed, no matching asset): return `nil`, negatively cached for **5 minutes** so a GitHub outage adds no per-request latency.

Fallback constant: `RELEASES_PAGE_URL = "https://github.com/LuxIudicium/Z-Codex/releases/latest"`.

## Controller (`StaticPagesController`)

- `z_codex` — resolve release (nil tolerated), render view.
- `download` — resolve; `release ? redirect_to(release.asset_url) : redirect_to(ZCodex::LatestRelease::RELEASES_PAGE_URL)` (302). The route always answers with a redirect; upstream failures never surface as 500s.

## Landing Page

File: `app/views/static_pages/z_codex.html.erb`. Uses the existing GW component system (`gw-window`, `gw-frame`, `gw-btn`, `gw-badge`). Hardcoded English copy, consistent with all other views.

1. **Hero window** — "Z-Codex" title; tagline *"Team build manager for Guild Wars 1 — spiritual successor to paw\*ned²"*; badges: *Free · Open source (MIT) · Unofficial tool*.
2. **Download block** — large `gw-btn` → `z_codex_download_path`.
   - Version resolved: label *"Download Z-Codex vX.Y.Z"* + meta *"Windows 10/11 · 64-bit · ~50 MB installer"*.
   - Version nil: plain *"Download Z-Codex"* (still useful — lands on the releases page).
   - Ghost button beside it: *"Source & issues on GitHub"* → repo URL.
3. **Features grid** — four cards distilled from the README:
   - Team composition (8 characters × 8 skills, build variants, filterable skill catalog)
   - Combat simulation (spike damage, armor, energy, conditions, monthly buffs)
   - Community builds (~1,460 builds / ~250 teams from PvXwiki build packs)
   - Comfort (French/English UI, dark theme, screenshots, undo/redo)
4. **File formats table** — `.zcx` (native), `.pn3` (legacy native), `.pwnd` (paw\*ned²), `.txt` (game template codes) with role and read/write columns.
5. **First-launch callout** — internet required once: ~8 MB skill catalog fetched from the public Guild Wars Wiki (~5 min), then the app runs offline.
6. **Legal line** — MIT © 2026 P. Vincent; not affiliated with ArenaNet/NCSOFT; link to repo LICENSE.

## Homepage Changes

File: `app/views/home/index.html.erb`.

- The "Z-Codex Compatible" badge becomes a `link_to z_codex_path` (same visual style).
- One extra link inside the Build Library card: *"Get Z-Codex →"* → landing page, alongside existing `/builds` and `/api-docs` links.

## Error Handling

- Service returns `nil` on any upstream problem; controller falls back to the releases-page redirect.
- Negative caching (5 min) prevents hammering GitHub and keeps latency flat during outages.
- Landing page degrades gracefully when version is unknown.

## Testing (RSpec)

`spec/requests/static_pages_spec.rb`:

- `GET /z-codex` → 200, contains download button.
- `GET /z-codex/download`, release stubbed → 302 to asset URL.
- `GET /z-codex/download`, service returns `nil` → 302 to releases page.

Service spec: parse/asset-selection logic tested by stubbing an internal fetch method at the HTTP boundary (no WebMock needed).

Homepage: assertion that the badge links to `/z-codex`.

## Out of Scope

Screenshots section, FAQ, French translation of the page, mirrored installers, version-feed API endpoint, dedicated Z-Codex controller namespace (promote later if tooling grows).
