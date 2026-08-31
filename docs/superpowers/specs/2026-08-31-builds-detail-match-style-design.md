# Build Detail Row — match style + single-line mobile skills

**Date:** 2026-08-31
**Status:** Approved design (pending implementation plan)

## Context / background

- The teambuild detail page (`/builds/:id`, `app/views/builds/show.html.erb`) renders one compact table row per character (`_character_row.html.erb`, introduced by the 2026-08-25 redesign):
  - Header line: gold character name + assignment badge on the left, two 26px round `gw-prof-chip` profession icons + template-code popover on the right (`ml-auto` flex).
  - Skills: 32px icons rendered with `html_image_simple`, grouped in `each_slice(4)` spans inside a `flex gap-x-2` container → up to two rows of 4 per character.
  - Then attribute pills and an italic notes line (build-specific extras).
- The match detail page (`/matches/:id`) renders team builds with a different visual language (`app/views/matches/_team_player.html.erb`): plain name on the left, right-floated `gw-imgs-inline` group with 33px profession images (`Profession#html_image`, bootstrap tooltip) + template-code popover, then a single-line skill bar of 55px icons (`TeamPlayer#html_skills`, `Skill#html_image`, tooltip after slot 8 via `<br>`).
- User request: make `/builds/:id` look more like the match page builds, **with all skills on one line on mobile**.

## Goal

Align the character row of `/builds/:id` with the match-page row style (raw profession images with tooltips, single-line skill bar), while guaranteeing that on mobile viewports all 8 skill icons fit on one line without horizontal scrolling.

## Design

Visual options were presented as browser mockups (desktop + 375px mobile wireframes) during brainstorming:

| Option | Description | Outcome |
|---|---|---|
| A — Faithful to match | Match-page icon sizes everywhere (33px professions / 55px skills), `<br>`-wrapped skill bar reusing `TeamPlayer#html_skills`-style markup | **Rejected**: the `<br>`-wrapped model-side HTML is pinned by `test/models/team_player_test.rb` and would wrap on mobile; nil-skill fallbacks from the JSON document don't fit that path cleanly |
| B — Keep chips | Keep 26px round chips, only de-slice the 32px skill line | **Rejected**: least "like the match page", not what was asked |
| C — Responsive dual-render | Match look on desktop (raw images + tooltips), 32px plain icons on mobile, one skill line at both breakpoints | **Chosen** |

### Approved decisions

| Decision | Choice |
|---|---|
| Profession icons | Raw images like the match page: `Profession#html_image` (33px, bootstrap tooltip) on desktop, `Profession#html_image_simple(size: 32)` on mobile. The round `gw-prof-chip` wrappers are dropped on this page |
| Skill icons | `Skill#html_image` (55px, tooltip) on desktop; `Skill#html_image_simple(size: 32)` on mobile |
| Skill layout | Single `flex flex-nowrap` line — no `each_slice(4)` grouping, no wrapping |
| Mobile fit | 8 × 32px + gaps ≈ 290px → fits a 375px viewport without scrolling |
| Build-specific extras | Kept: assignment badge, attribute pills, italic notes |
| Character name | Kept as gold `<strong>` (build characters are not linkable players) |
| Row layout mechanism | Keep current flex header + `ml-auto` right group (no `float`/`clear-both` migration) |
| Models / controllers / CSS / routes | No changes — reuse existing helpers and the existing `overflow-x-auto` wrapper in `_build_table.html.erb` |

Dual-render technique: each icon set is emitted twice (desktop variant `hidden sm:inline-block` / `sm:flex`, mobile variant `sm:hidden`), toggled by Tailwind breakpoints. Cost: duplicated `<img>` tags (≤ 10 per character) — negligible for ≤ 8 characters per composition.

## Detailed changes

### 1. `app/views/builds/_character_row.html.erb` (only view file changed)

```erb
<tr>
  <td>
    <!-- Header line: name + assignment left, prof images + popover right -->
    <span class="flex flex-wrap items-center gap-2">
      <strong class="text-gold-400"><%= row[:name].presence || "(unnamed)" %></strong>
      <% if row[:assignment].present? %><span class="gw-badge gw-badge--mode"><%= row[:assignment] %></span><% end %>
      <span class="ml-auto flex items-center gap-1 gw-imgs-inline">
        <span class="hidden sm:inline-block"><%= row[:primary_profession]&.html_image %></span>
        <span class="inline-block sm:hidden"><%= row[:primary_profession]&.html_image_simple(size: 32) %></span>
        <span class="hidden sm:inline-block"><%= row[:secondary_profession]&.html_image %></span>
        <span class="inline-block sm:hidden"><%= row[:secondary_profession]&.html_image_simple(size: 32) %></span>
        <%= render "application/template_code_popover",
              template_code: row[:template_code],
              name: row[:name].presence || "(unnamed)",
              primary_profession: row[:primary_profession],
              secondary_profession: row[:secondary_profession],
              assignment: row[:assignment] %>
      </span>
    </span>

    <!-- Skill line: all skills on one line, dual-render desktop/mobile -->
    <% skills = Array(row[:skills]) %>
    <div class="mt-1.5 hidden sm:flex flex-nowrap items-center gap-1.5 gw-imgs-inline">
      <% skills.each do |skill| %>
        <% if skill %>
          <%= skill.html_image %>
        <% else %>
          <%= image_tag "skills/Unknown_Junundu_Ability.jpg", title: "Unknown", width: 55, loading: "lazy" %>
        <% end %>
      <% end %>
    </div>
    <div class="mt-1.5 flex flex-nowrap items-center gap-1.5 gw-imgs-inline sm:hidden">
      <% skills.each do |skill| %>
        <% if skill %>
          <%= skill.html_image_simple(size: 32) %>
        <% else %>
          <%= image_tag "skills/Unknown_Junundu_Ability.jpg", title: "Unknown", width: 32, loading: "lazy" %>
        <% end %>
      <% end %>
    </div>

    <!-- Attribute pills + notes: unchanged -->
    <% if row[:attributes].any? %>
      <ul class="list-none m-0 mt-2 flex flex-wrap gap-1.5 p-0 text-sm">
        <% row[:attributes].each do |attribute| %>
          <li class="inline-flex items-center gap-2 rounded border border-gold-600/40 bg-ink-deep px-2 py-0.5"><span class="text-muted"><%= attribute[:name] %></span> <strong class="text-gold-400"><%= attribute[:points] %></strong></li>
        <% end %>
      </ul>
    <% end %>
    <% if row[:notes].present? %>
      <p class="italic text-sm text-note m-0 mt-1.5"><%= row[:notes] %></p>
    <% end %>
  </td>
</tr>
```

Notes:
- `Profession#html_image` / `Skill#html_image` already rescue `Propshaft::MissingAssetError` → `''`, so missing assets degrade silently.
- Unknown skills (nil) keep the existing `Unknown_Junundu_Ability.jpg` fallback at the matching size (55 / 32).
- Tooltip wiring (`data-controller="tooltip"` + bootstrap attrs) comes free with `html_image` and is already initialized globally by `app/javascript/controllers/tooltip_controller.js`.
- Desktop skill row (8 × 55px ≈ 470px) may exceed narrow desktop widths; the existing `overflow-x-auto` wrapper in `_build_table.html.erb` handles it.

### 2. `test/controllers/builds_controller_test.rb`

In `test "show renders compact rows with skills, attributes, notes and template popovers"`, keep the existing `assert_select "tbody img[width='32']", minimum: 8` (mobile copies remain in the DOM) and add:

```ruby
assert_select "tbody img[width='55']", minimum: 8
```

## Test plan

1. `bin/rails test test/controllers/builds_controller_test.rb` — targeted controller tests.
2. `bin/rails test` — full suite (guards `team_player` / match-page regressions; no match-side code is touched, so all existing assertions must still pass).
3. Manual viewport check: open `/builds/:id` at 375px width (all 8 skills on one line, no horizontal scroll inside the card) and at ≥ 640px (55px icons with tooltips, single line).
4. Verify a build with missing/unknown skills renders the fallback icon without breaking the line layout.

## Out of scope

- `/matches/:id` and `TeamPlayer#html_skills` (no changes; its markup is pinned by `test/models/team_player_test.rb`)
- Builds index page, download endpoint, visibility rules, variant-tabs behavior
- Refactoring `TeamPlayer#html_skills` side-effecting position writes (separate cleanup)
- Any new CSS components (the existing `gw-*` classes suffice)

## Verification

- Controller test suite green, including the updated show-page assertions.
- Side-by-side: `/builds/:id` row now mirrors `/matches/:id` row (raw prof images with tooltips on desktop, one-line skill bar at both breakpoints).
- No regressions in `matches` / `team_player` tests (zero match-side changes).
