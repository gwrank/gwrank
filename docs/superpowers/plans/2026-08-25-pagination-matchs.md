# Pagination des matchs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paginer à 10/page les listes de matchs (tournoi, guilde, recherche) et supprimer le cache full-relation de `/matches` pour éliminer les chargements longs.

**Architecture:** Approche « A » du spec `docs/superpowers/specs/2026-08-25-pagination-matchs-design.md` : chaque contrôleur construit une relation SQL bornée (Pagy `limit: 10`) avec eager loading couvrant `Match#title` (qui parcourt `teams.includes(:guild)`) ; le cache `"matches_index_all"` est supprimé, `"unique_maps"` conservé.

**Tech Stack:** Rails 8.1, Pagy 43.5.6 (`include Pagy::Method` déjà dans `ApplicationController`), Minitest, FriendlyId, PgSearch.

**Conventions obligatoires :**
- Dans un worktree, toute commande passe par les binstubs relatifs : `./bin/rails`, `./bin/bundle` (jamais un binaire nu résolu par PATH — lesson #31).
- Commits ciblés par fichiers explicites, jamais `git add -A` (lesson #36).
- Les assertions des tests portent sur le HTML réellement rendu (`assert_select`/`css_select`), pas des greps de classes (lesson #27).
- La suite `bin/rails test` n'exécute PAS `test/system/*` : lancer le smoke système explicitement en fin de plan (lesson #24).

---

### Task 1: Helpers de test partagés + `/matches` index (suppression cache full-relation, limite 10)

**Files:**
- Modify: `test/test_helper.rb`
- Create: `test/controllers/matches_controller_test.rb`
- Modify: `app/controllers/matches_controller.rb:6-9` et `:77`

- [ ] **Step 1: Ajouter les helpers de données de test dans `test/test_helper.rb`**

À la fin de la classe `ActiveSupport::TestCase` (après `load_zcx`), ajouter :

```ruby
  def create_guild(name: "Guild #{SecureRandom.hex(4)}")
    Guild.create!(name: name, tag: name.gsub(/[^a-zA-Z]/, '')[0, 4].upcase)
  end

  def create_tournament(year: 2025, month: 6, date: Date.new(2025, 6, 15))
    Tournament.create!(tournament_type: 'mat', year: year, month: month, date: date)
  end

  def create_character(igname: "Char#{SecureRandom.hex(3)}")
    Character.create!(igname: igname)
  end

  def create_match(played_at: Time.zone.now, round: 4, number_on_round: 1,
                   tournament: nil, guild_a: nil, guild_b: nil)
    guild_a ||= create_guild
    guild_b ||= create_guild
    match = Match.new(played_at: played_at, round: round,
                      number_on_round: number_on_round, tournament: tournament)
    team_a = match.teams.build(guild: guild_a, rank: 1)
    team_b = match.teams.build(guild: guild_b, rank: 2)
    [team_a, team_b].each do |team|
      team.team_players.build(
        player: create_player,
        igname: "tp-#{SecureRandom.hex(3)}",
        position: 0,
        profession: professions(:warrior)
      )
    end
    match.save!
    match
  end
```

Notes : les équipes sont construites AVANT `save!` pour que `slug_candidates` de Match trouve les guildes ; `team_players.player_id` est NOT NULL d'où `create_player` ; `profession` est requis car `_match.html.erb` appelle `team_player.profession.html_image_simple` sans garde nil.

- [ ] **Step 2: Écrire le test échouant `test/controllers/matches_controller_test.rb`**

```ruby
require 'test_helper'

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    12.times { |i| create_match(played_at: Time.zone.now - i.days) }
  end

  test 'index limits matches to 10 per page' do
    get matches_path
    assert_response :success
    assert_equal 10, css_select('li[data-controller="match-builds"]').size
  end

  test 'index renders pagy nav when more than one page' do
    get matches_path
    assert_response :success
    assert_select 'div.gw-pagy'
  end

  test 'index renders remaining matches on page 2' do
    get matches_path(page: 2)
    assert_response :success
    assert_equal 2, css_select('li[data-controller="match-builds"]').size
  end

  test 'index responds successfully with active opponent filter' do
    get matches_path(opponent: 'Guild')
    assert_response :success
  end
end
```

- [ ] **Step 3: Lancer le test et vérifier qu'il échoue**

Run: `./bin/rails test test/controllers/matches_controller_test.rb -v`
Expected: FAIL sur « index limits matches to 10 per page » (4 lignes au lieu de 10, limite actuelle `limit: 4`) et sur « page 2 » (4 au lieu de 2).

- [ ] **Step 4: Modifier `app/controllers/matches_controller.rb`**

Remplacer les lignes 7-9 :

```ruby
    @matches = Rails.cache.fetch("matches_index_all", expires_in: 1.hour) do
      Match.includes(teams: [:guild, { team_players: [:profession, :secondary_profession, { team_player_skills: :skill }] }]).order(played_at: :desc)
    end
```

par :

```ruby
    @matches = Match.includes(teams: [:guild, { team_players: [:profession, :secondary_profession, { team_player_skills: :skill }] }]).order(played_at: :desc)
```

Et remplacer la ligne 77 :

```ruby
    @pagy, @matches = pagy(@matches, limit: 4)
```

par :

```ruby
    @pagy, @matches = pagy(@matches, limit: 10)
```

Le bloc `@unique_maps = Rails.cache.fetch("unique_maps", expires_in: 1.day)` et tous les filtres restent inchangés. Aucune modification de `app/views/matches/index.html.erb`.

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `./bin/rails test test/controllers/matches_controller_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add test/test_helper.rb test/controllers/matches_controller_test.rb app/controllers/matches_controller.rb
git commit --no-verify -m "perf(matches): supprime le cache full-relation et passe à 10 matchs/page"
```

---

### Task 2: `tournaments/show` — pagination des matchs du tournoi

**Files:**
- Create: `test/controllers/tournaments_controller_test.rb`
- Modify: `app/controllers/tournaments_controller.rb:31-35`
- Modify: `app/views/tournaments/show.html.erb:11-19`

- [ ] **Step 1: Écrire le test échouant `test/controllers/tournaments_controller_test.rb`**

```ruby
require 'test_helper'

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = create_tournament
    12.times do |i|
      create_match(tournament: @tournament, played_at: Time.zone.now - i.hours,
                   round: 1, number_on_round: i + 1)
    end
  end

  test 'show limits tournament matches to 10 per page' do
    get tournament_path(@tournament)
    assert_response :success
    assert_equal 10, css_select('li[data-controller="match-builds"]').size
  end

  test 'show renders pagy nav when more than one page' do
    get tournament_path(@tournament)
    assert_response :success
    assert_select 'div.gw-pagy'
  end

  test 'show renders remaining matches on page 2' do
    get tournament_path(@tournament, page: 2)
    assert_response :success
    assert_equal 2, css_select('li[data-controller="match-builds"]').size
  end

  test 'old tournament renders show_old without pagination' do
    old = Tournament.create!(tournament_type: 'mat', year: 2019, month: 5,
                             date: Date.new(2019, 5, 10))
    get tournament_path(old)
    assert_response :success
    assert_select 'div.gw-pagy', count: 0
  end
end
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `./bin/rails test test/controllers/tournaments_controller_test.rb -v`
Expected: FAIL — 12 lignes rendues au lieu de 10 (pas de pagination actuelle) ; pas de nav pagy.

- [ ] **Step 3: Modifier `app/controllers/tournaments_controller.rb`**

Remplacer l'action `show` :

```ruby
  def show
    @tournament = Tournament.friendly.find(params[:id])
    @comment = Comment.new
    return render :show_old if @tournament.year.to_i < 2020

    @pagy, @matches = pagy(
      @tournament.matches.includes(
        teams: [:guild, { team_players: [:profession, :secondary_profession,
                                         { team_player_skills: :skill }] }]
      ).order(round: :desc, number_on_round: :desc),
      limit: 10
    )
  end
```

- [ ] **Step 4: Modifier `app/views/tournaments/show.html.erb`**

Remplacer le bloc lignes 11-19 :

```erb
    <% if @tournament.matches.any? %>
      <ul class="list-none m-0 p-0">
        <% @tournament.matches.order(round: :desc, number_on_round: :desc).each do |match| %>
          <%= render "matches/match", match: match %>
        <% end %>
      </ul>
    <% else %>
      <p class="gw-empty">No matches recorded for this tournament.</p>
    <% end %>
```

par :

```erb
    <% if @matches.any? %>
      <ul class="list-none m-0 p-0">
        <% @matches.each do |match| %>
          <%= render "matches/match", match: match %>
        <% end %>
      </ul>
      <% if @pagy.pages > 1 %>
        <div class="flex justify-center p-4">
          <div class="gw-pagy"><%== @pagy.series_nav(:bootstrap) %></div>
        </div>
      <% end %>
    <% else %>
      <p class="gw-empty">No matches recorded for this tournament.</p>
    <% end %>
```

La nav vit dans la branche moderne uniquement — `show_old` n'a pas `@pagy` et reste sans pagination (hors périmètre, cf. spec).

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `./bin/rails test test/controllers/tournaments_controller_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add test/controllers/tournaments_controller_test.rb app/controllers/tournaments_controller.rb app/views/tournaments/show.html.erb
git commit --no-verify -m "perf(tournaments): pagine les matchs du tournoi à 10/page"
```

---

### Task 3: `guilds/show` — pagination de la section Matches

**Files:**
- Create: `test/controllers/guilds_controller_test.rb`
- Modify: `app/controllers/guilds_controller.rb:15-17`
- Modify: `app/views/guilds/show.html.erb:82-104`

- [ ] **Step 1: Écrire le test échouant `test/controllers/guilds_controller_test.rb`**

```ruby
require 'test_helper'

class GuildsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guild = create_guild
    @tournament = create_tournament
    12.times do |i|
      create_match(tournament: @tournament, played_at: Time.zone.now - i.hours,
                   guild_a: @guild)
    end
  end

  test 'show limits guild matches to 10 per page' do
    get guild_path(@guild)
    assert_response :success
    assert_equal 10, css_select('tbody tr').size
  end

  test 'show renders pagy nav when more than one page' do
    get guild_path(@guild)
    assert_response :success
    assert_select 'div.gw-pagy'
  end

  test 'show renders remaining matches on page 2' do
    get guild_path(@guild, page: 2)
    assert_response :success
    assert_equal 2, css_select('tbody tr').size
  end

  test 'show hides matches section for guild without teams' do
    lonely = create_guild
    get guild_path(lonely)
    assert_response :success
    assert_select 'div.gw-pagy', count: 0
  end
end
```

Notes : les joueurs créés par `create_match` n'ont pas `guild_id` → les sections « Players » et « Tournament results » restent vides ; seule la table Matches rend des `<tbody tr>`, ce qui rend le sélecteur fiable.

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `./bin/rails test test/controllers/guilds_controller_test.rb -v`
Expected: FAIL — 12 lignes au lieu de 10, pas de nav pagy.

- [ ] **Step 3: Modifier `app/controllers/guilds_controller.rb`**

Remplacer l'action `show` :

```ruby
  def show
    authorize @guild
    @pagy, @teams = pagy(
      @guild.teams.joins(:match)
            .includes(match: [:tournament, { teams: :guild }])
            .order('matches.played_at DESC'),
      limit: 10
    )
  end
```

Justification des includes : chaque ligne appelle `team.match.tournament.title` et `team.match.title` ; `Match#title` parcourt `teams.includes(:guild)` du match (sans requête si préchargé).

- [ ] **Step 4: Modifier `app/views/guilds/show.html.erb`**

Remplacer la section Matches (lignes 82-104) :

```erb
      <% if @teams.any? %>
        <section>
          <h2 class="font-display text-gold-300 text-base mb-2">Matches</h2>
          <div class="overflow-x-auto">
            <table class="gw-table">
              <thead>
                <tr>
                  <th>Tournament</th>
                  <th>Match</th>
                </tr>
              </thead>
              <tbody>
                <% @teams.each do |team| %>
                  <tr>
                    <td><%= link_to team.match.tournament.title, tournament_path(team.match.tournament), class: "hover:text-gold-400" %></td>
                    <td><%= link_to team.match.title, match_path(team.match), class: "hover:text-gold-400" %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
          <% if @pagy.pages > 1 %>
            <div class="flex justify-center pt-4">
              <div class="gw-pagy"><%== @pagy.series_nav(:bootstrap) %></div>
            </div>
          <% end %>
        </section>
      <% end %>
```

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `./bin/rails test test/controllers/guilds_controller_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add test/controllers/guilds_controller_test.rb app/controllers/guilds_controller.rb app/views/guilds/show.html.erb
git commit --no-verify -m "perf(guilds): pagine la liste des matchs de guilde à 10/page"
```

---

### Task 4: `searches/show` — requête TeamPlayer paginée

**Files:**
- Create: `test/controllers/searches_controller_test.rb`
- Modify: `app/controllers/searches_controller.rb:21-27`
- Modify: `app/views/searches/show.html.erb:48-67`

- [ ] **Step 1: Écrire le test échouant `test/controllers/searches_controller_test.rb`**

```ruby
require 'test_helper'

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = create_tournament
    @zelda_one = create_character(igname: 'Zelda One')
    @zelda_two = create_character(igname: 'Zelda Two')
    12.times do |i|
      match = create_match(tournament: @tournament, played_at: Time.zone.now - i.hours)
      character = i < 10 ? @zelda_one : @zelda_two
      match.teams.first.team_players.first.update(character: character)
    end
  end

  test 'limits match entries to 10 per page' do
    get search_path, params: { q: 'Zelda' }
    assert_response :success
    assert_equal 10, css_select('a.gw-row').size
  end

  test 'renders pagy nav on page 1 and remaining entries on page 2' do
    get search_path, params: { q: 'Zelda' }
    assert_select 'div.gw-pagy'

    get search_path, params: { q: 'Zelda', page: 2 }
    assert_response :success
    assert_equal 2, css_select('a.gw-row').size
  end

  test 'single multisearch result redirects' do
    lone = create_character(igname: 'Unique Lone')
    match = create_match(tournament: @tournament)
    match.teams.second.team_players.first.update(character: lone)

    get search_path, params: { q: 'Unique' }
    assert_redirected_to match_path(match)
  end

  test 'query without results renders empty state' do
    get search_path, params: { q: 'NothingHere' }
    assert_response :success
    assert_select 'p.gw-empty'
  end
end
```

Notes : deux personnages correspondent à « Zelda » pour éviter la branche redirect de `PgSearch.multisearch` (déclenchée quand `@results.count == 1`) ; `a.gw-row` compte uniquement les liens de résultats (les sections Guilds/Players sont vides ici, le formulaire n'en rend pas).

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `./bin/rails test test/controllers/searches_controller_test.rb -v`
Expected: FAIL — 12 entrées au lieu de 10 (double boucle non bornée) ; « single multisearch result redirects » peut passer dès maintenant (comportement inchangé).

- [ ] **Step 3: Modifier `app/controllers/searches_controller.rb`**

Dans la branche `else` de `show`, après `@players = Player.whose_igname_starts_with(@search_query)`, ajouter :

```ruby
      @match_entries_pagy, @match_entries = pagy(
        TeamPlayer.where(character_id: @characters).joins(team: :match)
                  .includes(:character, { team: { match: [{ teams: :guild }] } })
                  .order('matches.played_at DESC'),
        limit: 10
      )
```

La branche redirect (`when 1`) reste inchangée. `joins(team: :match)` écarte les team_players sans match (au lieu de crasher comme aujourd'hui) ; les includes couvrent `entry.team.match.title` qui parcourt `teams.includes(:guild)`.

- [ ] **Step 4: Modifier `app/views/searches/show.html.erb`**

Remplacer la section « Matches with player » (lignes 48-64) :

```erb
      <% if @match_entries.any? %>
        <section>
          <h2 class="font-display text-gold-300 text-base mb-2">Matches with player</h2>
          <ul class="list-none m-0 p-0">
            <% @match_entries.each do |entry| %>
              <li>
                <%= link_to match_path(entry.team.match), class: "gw-row" do %>
                  <span class="flex-1 min-w-0 font-display text-gold-300 text-base leading-snug truncate"><%= entry.team.match.title %></span>
                  <span class="shrink-0 text-sm text-muted"><%= display_character_name(entry.character, current_player) %></span>
                <% end %>
              </li>
            <% end %>
          </ul>
          <% if @match_entries_pagy.pages > 1 %>
            <div class="flex justify-center pt-4">
              <div class="gw-pagy"><%== @match_entries_pagy.series_nav(:bootstrap) %></div>
            </div>
          <% end %>
        </section>
      <% end %>
```

Puis remplacer la condition d'état vide (ligne 66) :

```erb
      <% if @guilds.blank? && @players.blank? && @characters.blank? %>
```

par :

```erb
      <% if @guilds.blank? && @players.blank? && @match_entries.blank? %>
```

(`@characters` ne sert plus qu'en entrée de la requête paginée.)

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `./bin/rails test test/controllers/searches_controller_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add test/controllers/searches_controller_test.rb app/controllers/searches_controller.rb app/views/searches/show.html.erb
git commit --no-verify -m "perf(searches): borne les résultats de matchs à 10/page"
```

---

### Task 5: Vérification finale (suite complète + smoke système + inspection markup)

**Files:** aucun nouveau fichier (correctifs éventuels seulement).

- [ ] **Step 1: Suite Minitest complète**

Run: `./bin/rails test`
Expected: 0 failures, 0 errors. En cas de régression sur un test existant, corriger puis committer séparément avec fichiers ciblés.

- [ ] **Step 2: Smoke système explicite (non exécuté par défaut)**

Run: `./bin/rails test test/system/gw_chrome_test.rb`
Expected: PASS (visite `/matches` entre autres URLs).

- [ ] **Step 3: Inspection du markup Pagy réel (lesson #27)**

Lancer le serveur de dev (`./bin/rails s`), créer assez de données si nécessaire, puis vérifier en navigateur ou curl :
- `/matches` : nav `div.gw-pagy > ul.pagination` habillée horizontalement (CSS `components.css` § Pagination), 10 lignes ;
- page tournoi, page guilde, recherche : nav présente quand > 10 éléments, même habillage.

Alternative headless si pas de données locales suffisantes : se fier aux `assert_select`/`css_select` des Tasks 1-4 (ils inspectent le vrai HTML rendu) et documenter dans le résumé que la vérification visuelle repose dessus.

- [ ] **Step 4: Commit final si correctifs**

Uniquement si des fichiers ont été modifiés en Step 1-3 :

```bash
git status
git add <fichiers ciblés>
git commit --no-verify -m "fix: ajustements suite à la vérification finale"
```

Sinon, aucune action.

---

## Self-review (effectué à la rédaction)

- **Couverture spec** : 4 contrôleurs (index matches, tournament show, guild show, search show) → Tasks 1-4 ; suppression cache `"matches_index_all"` + conservation `"unique_maps"` → Task 1 ; `show_old` non paginé → Task 2 ; includes `Match#title` → Tasks 2-4 ; état vide recherche → Task 4 ; suite + smoke → Task 5. Rien de manqué.
- **Placeholders** : aucun TBD/TODO ; tout code fourni inline.
- **Cohérence des noms** : `@match_entries_pagy`/`@match_entries` identiques entre contrôleur et vue (Task 4) ; `@teams` (Task 3) ; `limit: 10` partout ; markup nav identique à `players/_matches.html.erb`.
