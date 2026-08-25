# Design — Pagination des matchs sur toutes les pages

**Date** : 2026-08-25
**Statut** : Validé en brainstorming, sections 1 et 2 approuvées

## Problème

Trois pages chargent tous leurs matchs sans pagination ni eager loading cohérent :
`tournaments/show` (boucle sur tous les matchs du tournoi), `guilds/show` (table de
toutes les équipes), `searches/show` (double boucle non bornée personnages →
team_players → matchs). Par ailleurs `/matches`, déjà paginé à 4/page, reste lent
car le contrôleur met **toute la relation Match avec includes profonds** en cache
Rails (`"matches_index_all"`, TTL 1 h) et la désérialise intégralement à chaque
requête — cause racine des chargements longs.

## Décisions

- Approche **A — complète** : pagination 10/page partout + suppression du cache
  full-relation + suppression des N+1.
- Taille de page : **10 éléments partout** (cohérent avec `players/show`).
- Gem : Pagy (déjà installé, v43.5.6, `include Pagy::Method` dans
  `ApplicationController`). Markup nav identique à l'existant :
  `<div class="gw-pagy"><%== @pagy.series_nav(:bootstrap) %></div>`, conditionnel
  `if @pagy.pages > 1`.

## Modifications

### 1. `app/controllers/matches_controller.rb` — `index`

- Supprimer `Rails.cache.fetch("matches_index_all", …)` ; construire directement
  `Match.includes(teams: [:guild, { team_players: [:profession,
  :secondary_profession, { team_player_skills: :skill }] }]).order(played_at: :desc)`
- Conserver le cache `"unique_maps"` (TTL 1 jour)
- Filtres inchangés (chaînage SQL direct au lieu de la relation désérialisée)
- `pagy(@matches, limit: 10)` (au lieu de 4)

### 2. `app/controllers/tournaments_controller.rb` — `show`

- Si `@tournament.year.to_i < 2020` : `render :show_old` inchangé (table minimale,
  pas de pagination)
- Sinon :
  ```ruby
  @pagy, @matches = pagy(
    @tournament.matches.includes(
      teams: [:guild, { team_players: [:profession, :secondary_profession,
                                        { team_player_skills: :skill }] }]
    ).order(round: :desc, number_on_round: :desc),
    limit: 10
  )
  ```

### 3. `app/controllers/guilds_controller.rb` — `show`

```ruby
@pagy, @teams = pagy(
  @guild.teams.joins(:match).includes(
    match: [:tournament, { teams: :guild }]
  ).order('matches.played_at DESC'),
  limit: 10
)
```
Justification includes : chaque ligne affiche `team.match.tournament.title` et
`team.match.title` ; `Match#title` parcourt `teams.includes(:guild)` de ce match.

### 4. `app/controllers/searches_controller.rb` — `show`

- Branche redirect résultat unique : inchangée
- Remplacer la double boucle vue par une requête paginée :
  ```ruby
  @match_entries_pagy, @match_entries = pagy(
    TeamPlayer.where(character_id: @characters).joins(team: :match)
              .includes(:character, { team: { match: [{ teams: :guild }] } })
              .order('matches.played_at DESC'),
    limit: 10
  )
  ```

### Vues

- `app/views/matches/index.html.erb` : **aucune modification**
- `app/views/tournaments/show.html.erb` : boucle sur `@matches` (plus
  `@tournament.matches.order(...)`), nav conditionnelle sous la liste
- `app/views/guilds/show.html.erb` : section Matches itère `@teams`, nav
  conditionnelle
- `app/views/searches/show.html.erb` : section « Matches with player » itère
  `@match_entries` (`entry.team.match.title`,
  `display_character_name(entry.character, current_player)`), condition
  d'affichage `@match_entries.any?`, nav conditionnelle rendue depuis
  `@match_entries_pagy` (`@match_entries_pagy.pages > 1`,
  `@match_entries_pagy.series_nav(:bootstrap)`) — même convention que
  `players/_matches.html.erb` avec `@matches_pagy`

## Cas limites

- Clé de cache supprimée : l'entrée existante expire seule (TTL 1 h), rien à migrer
- Guilde sans équipe / recherche sans personnage : sections masquées comme
  aujourd'hui (`any?`)
- Fragment cache `<% cache @matches %>` de l'index : clé différente par page
  (voulu), conservé
- `show_old` (< 2020) : non paginé, hors périmètre
- Filtres actifs de `/matches` : comportement identique, simplement 10/page

## Tests

Minitest, nouveaux fichiers (aucun test contrôleur existant pour ces contrôleurs ;
fixtures limitées à skills/professions → création manuelle des records en setup) :

- `test/controllers/matches_controller_test.rb` : 200 OK ; ≤ 10 lignes rendues
  avec 12+ matchs ; markup pagy présent quand pages > 1 ; réponse 200 avec filtre
  actif
- `test/controllers/tournaments_controller_test.rb` : 200 OK ; pagination du
  tournoi moderne ; `show_old` non paginé pour année < 2020
- `test/controllers/guilds_controller_test.rb` : 200 OK ; ≤ 10 équipes rendues ;
  nav présente si > 10
- `test/controllers/searches_controller_test.rb` : section matches bornée à 10
  entrées ; aucun crash si aucun personnage ne correspond

Vérifications : suite Minitest complète + smoke système existant (`gw_chrome_test`
visite `/matches`) vert. Lesson #27 : vérifier le HTML réellement rendu par Pagy
(smoke request + inspection du markup), pas seulement des greps de classes.
