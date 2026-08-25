# Task 4 — Archives: matches, players, scrims, guilds, tournaments

## Status: DONE (both commits verified)

## Commit A — 05f49291 matches, players, scrims, guilds
- [x] Controllers: `layout "gw"` → matches, players, scrims, guilds (no guilds/* namespace exists)
- [x] searches/_form.html.erb → gw-input/gw-btn (rendered by 3 of my pages; searches/show left for Task 5 "recherche")
- [x] components.css: one compat rule for `.gw-btn.btn-outline-primary` (health-chart JS toggles bootstrap classnames; controller untouched)
- [x] matches: index (+ collapsible filters), show, new, _filters, _match (gw-row + preserved match-builds popup), _team_player (untouched — popover contract already valid), _team_stats (tooltip controller + native <details>, vanilla JS kept, dead bootstrap JS removed)
- [x] players: index, show, _matches
- [x] scrims: index, show
- [x] guilds: index, _guild, show, new (_form.html.erb is empty/unrendered — nothing to migrate)
- [x] rel="noopener noreferrer" added on touched target="_blank" links
- Verify: 199 runs / 5 failures / 0 errors ✓ ; yarn build + build:css OK ✓

## Commit B — 276e42e1 tournaments
- [x] tournaments_controller → layout "gw"
- [x] index: season card grid (gw-parchment cards) + collapsible migrated filters
- [x] _filters: GW form treatment
- [x] show / show_old: windows + gw-table results + comments window
- [x] Year partials {2008,2009,2010}/**: ZERO legacy classes (pure <tr> rows, no class attrs at all) — mechanical mapping is a no-op
- Verify: 199/5/0 exact baseline ✓ ; grep -rl "mpl-\|class=\"table\|btn btn-" app/views/tournaments = 0 ✓ ; overall mpl- files = 20, all in later-task scope (documentation/statistics/streamers/searches → Task 5; admin + old navbar/footer/preloader → later chrome tasks)

## Notes / decisions
- ScrimsControllerTest ×3 fail on pre-existing 302 auth redirects BEFORE content assertions — markup can't affect them. HomeControllerTest ×2 pre-existing home-page content failures.
- Scratch smoke tests (signed-in rendering of every migrated page incl. match/tournament fixtures) passed 9/9 then deleted before commit.
- Health-chart buttons keep targets/actions/values + canvas verbatim; active-mode visual state bridged via CSS alias for the bootstrap classnames the controller toggles.
- No score field invented for match rows (none exists on the model); kept ranks/names/round/date/winner-trophy as before.
