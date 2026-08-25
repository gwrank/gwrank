# Homepage Vitrine Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bot-only homepage with a pure showcase page (compact hero + bento grid presenting the 4 product pillars), move the current homepage content to a new `/bot` documentation page, and update the top navigation to `Builds · Bot & Docs · Archives`.

**Architecture:** Static ERB only — no new models, no DB changes. The `/bot` page joins the existing `DocumentationController` family (breadcrumb + sidebar pattern). Nav items come from the `GWLayoutHelper#main_nav_items` helper consumed by `_gw_topbar.html.erb`.

**Tech Stack:** Rails 8.1, Tailwind CSS v4 (existing GW design system: `gw-window`, `gw-frame`, `gw-btn`, `gw-doc`, gold palette), Minitest integration tests.

**Spec:** `docs/superpowers/specs/2026-08-25-homepage-vitrine-design.md`

---

### Task 1: Capture test suite baseline

The current `HomeControllerTest` is already red (2 failures — it asserts an older homepage that displayed scrim/queue stats). Record the baseline so we can verify at the end that nothing else regressed.

- [ ] **Step 1: Run the full test suite and record the summary**

Run: `bin/rails test 2>&1 | tail -15`
Expected: some number of runs/failures/errors. **Write down the counts** (expected: at least the 2 known `HomeControllerTest` failures; anything else pre-existing stays untouched). This output is the reference for Task 5 verification.

---

### Task 2: Dedicated `/bot` page (route + action + view + sidebar entry)

**Files:**
- Create: `test/controllers/documentation_controller_test.rb`
- Modify: `config/routes.rb` (after line 62, alongside the other doc routes)
- Modify: `app/controllers/documentation_controller.rb` (new action after `teambuild`)
- Create: `app/views/documentation/bot.html.erb`
- Modify: `app/views/documentation/_sidebar.html.erb` (new first entry in Documentation list)

- [ ] **Step 1: Write the failing test**

Create `test/controllers/documentation_controller_test.rb`:

```ruby
require "test_helper"

class DocumentationControllerTest < ActionDispatch::IntegrationTest
  test "GET /bot renders bot presentation with unified Discord invite" do
    get bot_path

    assert_response :success
    assert_select 'body', text: /GWRank Discord Bot/
    assert_select "a[href='https://discord.com/oauth2/authorize?client_id=788778440877801504']", text: 'Add Bot to Discord'
    assert_select "a[href='https://discord.gg/jqShPZBkcj']", text: 'Join our Discord'
    assert_select 'body', text: /Build Commands/
    assert_select 'body', text: /Team Build Commands/
    assert_select 'body', text: /How to Use the Bot/
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/documentation_controller_test.rb`
Expected: FAIL with `NameError: undefined local variable or method 'bot_path'` (route does not exist yet).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, inside the `# Documentation routes` block, after the `get '/teambuild'` line (line 62), add:

```ruby
  get '/bot', to: 'documentation#bot', as: :bot
```

- [ ] **Step 4: Add the controller action**

In `app/controllers/documentation_controller.rb`, after the `teambuild` action (line 29), add:

```ruby
  def bot
    render :bot
  end
```

- [ ] **Step 5: Create the view**

Create `app/views/documentation/bot.html.erb` (content moved from the old homepage, dressed like sibling doc pages; login/logout block dropped — topbar handles auth; invite unified to the footer's `jqShPZBkcj`):

```erb
<div class="space-y-4">
  <div class="gw-window gw-frame p-6 leading-relaxed">
    <%= render 'documentation/breadcrumb', page: 'Discord Bot' %>

    <h1 class="font-display text-gold-300 text-2xl tracking-wide m-0 mt-3">GWRank Discord Bot</h1>
    <p class="text-muted mt-1 mb-0">Share builds and organize tournaments from your Discord server</p>

    <div class="flex gap-6 mt-6">
      <%= render 'documentation/sidebar' %>
      <div class="flex-1 min-w-0 gw-doc space-y-8">

        <section class="text-center space-y-4">
          <p class="text-muted max-w-2xl mx-auto">
            Share builds, teambuilds and organize automated tournaments. Add our bot to your Discord server and start using slash commands.
          </p>
          <div class="flex flex-wrap justify-center gap-3">
            <%= link_to 'Add Bot to Discord', 'https://discord.com/oauth2/authorize?client_id=788778440877801504', target: '_blank', rel: 'noopener noreferrer', class: 'gw-btn' %>
            <%= link_to 'Join our Discord', 'https://discord.gg/jqShPZBkcj', target: '_blank', rel: 'noopener noreferrer', class: 'gw-btn gw-btn--ghost' %>
          </div>
        </section>

        <section>
          <h2>Command Documentation</h2>

          <div class="grid gap-4 sm:grid-cols-2">
            <div class="gw-doc gw-parchment rounded-md border border-gold-600/40 p-4 space-y-3">
              <h3>Build Commands</h3>
              <p>Display individual Guild Wars builds from template codes. Share your character builds with others.</p>
              <%= link_to 'View Build Commands', build_doc_path, class: 'gw-btn' %>
            </div>

            <div class="gw-doc gw-parchment rounded-md border border-gold-600/40 p-4 space-y-3">
              <h3>Team Build Commands</h3>
              <p>Display complete team builds from pawned2 exports. Share your team compositions and strategies.</p>
              <%= link_to 'View Team Build Commands', teambuild_doc_path, class: 'gw-btn' %>
            </div>

            <div class="gw-doc gw-parchment rounded-md border border-gold-600/40 p-4 space-y-3">
              <h3>Automated Tournament</h3>
              <p>Daily AT queue management and scheduling. Organize your daily automated tournaments.</p>
              <%= link_to 'View AT Commands', at_doc_path, class: 'gw-btn' %>
            </div>

            <div class="gw-doc gw-parchment rounded-md border border-gold-600/40 p-4 space-y-3">
              <h3>Monthly AT</h3>
              <p>Monthly Automated Tournament scheduling and registration. Organize your monthly tournaments.</p>
              <%= link_to 'View MAT Commands', mat_doc_path, class: 'gw-btn' %>
            </div>
          </div>
        </section>

        <section>
          <h2>How to Use the Bot</h2>
          <ol class="list-decimal list-inside space-y-1">
            <li>Click "Add Bot to Discord" above to add the bot to your server</li>
            <li>Ensure the bot has the necessary permissions</li>
            <li>Use <code>/build</code> to share your character builds</li>
            <li>Use <code>/teambuild</code> to share your team compositions</li>
            <li>Use <code>/at</code> and <code>/mat</code> commands to organize tournaments</li>
            <li>Explore all commands using the documentation links above</li>
          </ol>
        </section>

      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 6: Add the sidebar entry**

In `app/views/documentation/_sidebar.html.erb`, insert as the **first** `<li>` of the Documentation list (before the `Player Commands` item, line 6):

```erb
        <li><%= link_to 'Discord Bot', bot_path, class: "block border-l-2 pl-3 py-1 #{current_page?(bot_path) ? 'border-gold-500 text-gold-400' : 'border-hairline text-muted hover:text-parchment'}" %></li>
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bin/rails test test/controllers/documentation_controller_test.rb`
Expected: `1 runs, 1 failures, 0 errors` → now `1 runs, 0 failures, 0 errors` (PASS).

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/documentation_controller.rb app/views/documentation/bot.html.erb app/views/documentation/_sidebar.html.erb test/controllers/documentation_controller_test.rb
git commit -m "feat(web): dedicated /bot page for Discord bot & docs"
```

---

### Task 3: Showcase homepage (hero + bento grid)

**Files:**
- Modify: `test/controllers/home_controller_test.rb` (full rewrite — replaces the 2 stale red tests)
- Modify: `app/controllers/home_controller.rb`
- Modify: `app/views/home/index.html.erb` (full rewrite)

- [ ] **Step 1: Rewrite the failing test**

Replace the entire content of `test/controllers/home_controller_test.rb` with:

```ruby
require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the showcase homepage" do
    get root_path

    assert_response :success
    assert_select 'body', text: /Builds, teambuilds and a Discord bot — everything your guild needs to prepare its GvG matches\./
    assert_select "a[href='https://discord.com/oauth2/authorize?client_id=788778440877801504']", text: 'Add Bot to Discord'
    assert_select "a[href='/builds']", text: 'Browse Builds'
    assert_select 'body', text: /Build & Teambuild Library/
    assert_select 'body', text: /Discord Bot/
    assert_select 'body', text: /Open Scrims/
    assert_select 'body', text: /Tournament Archives/
    assert_select 'body', text: /Documentation/
  end
end
```

(The tagline assertion uses an em dash `—`; keep it byte-identical with the view copy below.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: FAIL — the current homepage does not contain the tagline or the pillar cards.

- [ ] **Step 3: Clean up the controller**

Replace the entire content of `app/controllers/home_controller.rb` with:

```ruby
class HomeController < ApplicationController
  def index
  end
end
```

(Removes `@queue_count`, `@recent_scrims`, `@scrims_count` — unused since the old redesign; no dynamic data in a pure showcase page.)

- [ ] **Step 4: Rewrite the view**

Replace the entire content of `app/views/home/index.html.erb` with:

```erb
<div class="space-y-6">
  <section class="gw-window gw-frame">
    <div class="text-center px-6 py-10 sm:py-14 space-y-4">
      <h1 class="font-display text-gold-300 text-4xl tracking-[0.35em] m-0">GWRANK</h1>
      <p class="italic text-lg text-muted max-w-xl mx-auto m-0">
        Builds, teambuilds and a Discord bot — everything your guild needs to prepare its GvG matches.
      </p>
      <div class="flex flex-wrap justify-center gap-3 pt-2">
        <%= link_to 'Add Bot to Discord', 'https://discord.com/oauth2/authorize?client_id=788778440877801504', target: '_blank', rel: 'noopener noreferrer', class: 'gw-btn' %>
        <%= link_to 'Browse Builds', builds_path, class: 'gw-btn gw-btn--ghost' %>
      </div>
    </div>
  </section>

  <section class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
    <div class="sm:col-span-2 lg:col-span-2 lg:row-span-2 gw-doc gw-window gw-frame p-6 sm:p-8 flex flex-col gap-3">
      <span class="font-display text-gold-500 text-xs tracking-widest uppercase">Z-Codex Compatible</span>
      <h2 class="m-0">📜 Build &amp; Teambuild Library</h2>
      <p class="text-muted m-0">
        Browse community builds and full teambuilds stored in the open Z-Codex (<code>.zcx</code>) format — professions,
        attributes, elite skills and player assignments included. Download any teambuild and open it straight into
        Z-Codex to iterate on your composition.
      </p>
      <p class="text-muted m-0">
        Every build is versioned, tagged by game mode and strategy, and exposed through a REST API so your own tools
        can consume it.
      </p>
      <p class="mt-auto m-0 space-x-4">
        <%= link_to 'Browse the library →', builds_path %>
        <%= link_to 'API documentation', '/api-docs' %>
      </p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">🤖 Discord Bot</h3>
      <p class="text-muted m-0">
        Share builds and teambuilds in your server with <code>/build</code> and <code>/teambuild</code>. Organize your
        guild's daily AT and monthly mAT registrations without leaving Discord.
      </p>
      <p class="mt-auto m-0"><%= link_to 'Bot & Docs →', bot_path %></p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">⚔️ Open Scrims</h3>
      <p class="text-muted m-0">
        Queue up solo or as a guild, get teams formed and play structured GvG scrimmages with score tracking.
      </p>
      <p class="mt-auto m-0"><%= link_to 'Join the queue →', scrims_path %></p>
    </div>

    <div class="sm:col-span-2 lg:col-span-2 gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">🏆 Tournament Archives</h3>
      <p class="text-muted m-0">
        Years of Automated Tournament history — brackets, matches, rosters and ratings preserved and searchable.
      </p>
      <p class="mt-auto m-0"><%= link_to 'Explore the archives →', tournaments_path %></p>
    </div>

    <div class="gw-doc gw-window gw-frame p-5 flex flex-col gap-2">
      <h3 class="m-0">📖 Documentation</h3>
      <ul class="list-none m-0 p-0 space-y-1 text-sm text-muted">
        <li><code>/build</code> — share single builds</li>
        <li><code>/teambuild</code> — pawned2 teambuilds</li>
        <li><code>/at</code> · <code>/mat</code> — tournaments</li>
        <li><code>/scrim</code> — scrim commands</li>
      </ul>
      <p class="mt-auto m-0"><%= link_to 'All commands →', bot_path %></p>
    </div>
  </section>
</div>
```

Desktop (≥ lg) auto-placement yields the validated 3×3 arrangement: flagship spans rows 1–2 cols 1–2; Bot lands at row 1 col 3; Scrims row 2 col 3; Archives (col-span-2) row 3 cols 1–2; Documentation row 3 col 3. Tablet (sm): flagship and Archives go full width. Mobile: single column in DOM order.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: `1 runs, 0 failures, 0 errors` (PASS).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/home_controller.rb app/views/home/index.html.erb test/controllers/home_controller_test.rb
git commit -m "feat(home): showcase homepage with compact hero and bento grid"
```

---

### Task 4: Top navigation « Builds · Bot & Docs · Archives » + brand subtitle + invite cleanup

**Files:**
- Modify: `app/helpers/gw_layout_helper.rb` (`main_nav_items`)
- Modify: `app/views/application/_gw_topbar.html.erb:5` (brand subtitle)
- Modify: `app/views/statistics/index.html.erb:20` (unify Discord invite)
- Modify: `test/controllers/home_controller_test.rb` (append a nav test)

- [ ] **Step 1: Append the failing nav test**

Add this test inside `class HomeControllerTest` in `test/controllers/home_controller_test.rb`:

```ruby
  test "top navigation shows Builds, Bot & Docs and Archives" do
    get root_path

    assert_response :success
    assert_select 'a', text: 'Builds'
    assert_select 'a', text: 'Bot & Docs'
    assert_select 'a', text: 'Archives'
    assert_select 'small', text: 'Guild Wars · GvG Tools'
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: FAIL — no `Bot & Docs` nav link yet, subtitle still `Guild Wars · Hall of Heroes`.

- [ ] **Step 3: Update the nav helper**

Replace the entire content of `app/helpers/gw_layout_helper.rb` with:

```ruby
module GWLayoutHelper
  def main_nav_items
    [
      { label: "Builds", path: builds_path },
      { label: "Bot & Docs", path: bot_path },
      { label: "Archives", path: tournaments_path }
    ]
  end

  def gw_nav_active?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end
end
```

- [ ] **Step 4: Update the brand subtitle**

In `app/views/application/_gw_topbar.html.erb` line 5, change:

```erb
      <small class="block font-body font-normal tracking-wide text-muted text-[10px] uppercase">Guild Wars · Hall of Heroes</small>
```

to:

```erb
      <small class="block font-body font-normal tracking-wide text-muted text-[10px] uppercase">Guild Wars · GvG Tools</small>
```

- [ ] **Step 5: Unify the remaining Discord invite**

In `app/views/statistics/index.html.erb` line 20, change the URL `https://discord.gg/Gjefv7GJ9g` to `https://discord.gg/jqShPZBkcj` (last occurrence of the old invite in the app — the footer already uses `jqShPZBkcj`).

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/controllers/home_controller_test.rb test/controllers/documentation_controller_test.rb`
Expected: `3 runs, 0 failures, 0 errors` (PASS).

- [ ] **Step 7: Full suite regression check against Task 1 baseline**

Run: `bin/rails test 2>&1 | tail -15`
Expected: same or better than the Task 1 baseline — the previously-red `HomeControllerTest` failures are gone, `DocumentationControllerTest` passes, and **no new failures/errors** appear anywhere else.

- [ ] **Step 8: Manual smoke test**

Run: `bin/rails server` then check in a browser (and at ~380px width for mobile):
- `http://localhost:3000/` — hero + 5 bento cards, layout matches the validated mockup (flagship Build Library card big, left, 2×2 on desktop)
- `http://localhost:3000/bot` — breadcrumb + sidebar (with « Discord Bot » entry highlighted) + bot content
- Top nav reads `Builds · Bot & Docs · Archives`; brand subtitle reads `Guild Wars · GvG Tools`

Stop the server afterwards.

- [ ] **Step 9: Commit**

```bash
git add app/helpers/gw_layout_helper.rb app/views/application/_gw_topbar.html.erb app/views/statistics/index.html.erb test/controllers/home_controller_test.rb
git commit -m "feat(nav): Builds / Bot & Docs / Archives top menu"
```

---

## Out of scope (from spec)

- i18n / language switcher, dynamic data on the homepage, redesigning the Builds/Scrims/Archives pages themselves, logo/favicon, `public/404.html` & `public/500.html` static pages (« Return to Hall of Heroes »).
