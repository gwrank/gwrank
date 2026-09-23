# Synchro incrémentale /teambuilds : signaler les suppressions (tombstones)

## Statut : TERMINÉ — non commité (validation utilisateur en cours)

## Cause racine

Suppressions physiques (API `destroy!` + cascade `dependent: :destroy` du compte Player),
aucun tombstone ; `updated_since` filtre les lignes vivantes uniquement → les suppressions
sont invisibles pour la synchro incrémentale (fantômes chez Z-Codex).

## Approche retenue : table de tombstones (pas de soft-delete)

Soft-delete écarté : contaminerait chaque requête, exigerait un index unique partiel et des
règles de résurrection. La table annexe garde `teambuilds` intacte.

- [x] Migration `teambuild_deletions` : `player_id` FK **nullify** (les tombstones publics
      survivent à la suppression de compte), `source_uuid`, `visibility`, `deleted_at`, timestamps ;
      index sur `deleted_at` et `(player_id, source_uuid)`
- [x] Modèle `TeambuildDeletion` : scopes `visible_to(player)` (public OU à soi — règle
      `visible_to` d'avant suppression), `deleted_since(time)`
- [x] `Teambuild#after_destroy` → écrit la tombstone (couvre API ET cascade compte)
- [x] `Teambuilds::Ingest` : (re)création d'un uuid → purge des tombstones correspondantes
- [x] Contrôleur index/export : si `updated_since` présent → `deletions: [{sourceId, deletedAt}]`
- [x] Swagger : schéma `TeambuildDeletion` + descriptions, YAML régénéré (rswag)
- [x] Tests rswag : propre build supprimé → listé ; public d'autrui supprimé → listé ;
      privé d'autrui supprimé → absent
- [x] Tests minitest modèle : tombstone au destroy, purge au re-ingest, cascade player,
      scope deleted_since

## Vérification

- rspec 25/25 (2 nouveaux exemples updated_since) ; minitest 281 runs, seules les 3
  failures Scrims préexistantes sur main ; YAML OpenAPI régénéré.
- Preuve HTTP réelle (serveur dev + curl) : re-création post-suppression → build dans
  `teambuilds` ET tombstone purgée du flux ; public d'autrui supprimé → listé avec
  `deletedAt` ; privé d'autrui → absent (pas de fuite) ; sans `updated_since` → pas de clé
  `deletions` (contrat inchangé).

Décisions : tombstones conservés sans limite de durée (lignes minuscules, synchro correcte
même après un an) ; pas de pagination sur `deletions`.

---

# Refonte UI « Client GW fidèle » — Suivi

## Statut : TERMINÉ (branche `redesign/gw-ui`, en attente de revue visuelle + merge)

- [x] Task 0 — Fondations Tailwind v4, tokens, composants, chrome (dd9b1bd2)
- [x] Task 1 — Portage Builds (86b87089)
- [x] Task 2 — Home & statiques (1e14e400)
- [x] Task 3 — Auth Devise, profil, token API (bf55e7fd)
- [x] Task 4 — Archives matches/players/scrims/guilds/tournaments (276e42e1 → d5575df4)
- [x] Task 5 — Statistics/streamers/docs/search + relocation _gw_card (df8e9c98)
- [x] Task 6 — Administration (5848d9e4)
- [x] Task 7 — Bascule finale, purge legacy, pages 404/500, tests système (edd5e81b → 21f382ba)
- [x] Retours utilisateur : bouton Discord home, pagination horizontale, chips d'attributs, loupe recherche (b1691e36, 8de0e2f4)
- [x] Revue finale : debug logging excisé (901b4561), highlight Pagy, vendor JS purgé, tokens, a11y, touch targets (0f9cfa3a)
- [x] Nav mobile à onglets défilants (08cf834e)

## Revue (post-implémentation)

**Vérification :** `bin/rails test` → 199 runs / 5 échecs préexistants (Home ×2, Scrims ×3, auth-redirects antérieurs à la branche) / 0 errors · `bundle exec rspec` → 17/0 · système → 4/29 verts · grep legacy (mpl-/monsterplay/data-bs-/fancybox) → 0 · routes/models/API intacts (diff 0 ligne) · builds JS+CSS OK.

**Process :** chaque tâche = implémenteur dédié + revue conformité spec + revue qualité + boucle de correctifs re-revue. ~22 commits conventionnels.

**Hors périmètre respecté :** aucun changement models/routes/API.

## Reste ouvert (hors branche)

- Connexion Discord : cause externe confirmée (client secret rejeté — `invalid_client`) ; l'utilisateur doit régénérer le secret dans le portail développeur. Un patch local non commité ([OMNIAUTH-DEBUG]) reste dans le worktree le temps du diagnostic — à retirer avant merge.
- 5 échecs de tests préexistants sur main (Home/Scrims) — à traiter séparément.

## Review — retours Z-Codex v3 (branche zcx-api-v3, 25/08)

Livrés (7 commits, spec: docs/superpowers/specs/2026-08-25-zcx-api-v3-retours-design.md) :
- If-Match/412 optionnel sur PUT, basé document_hash ; ETag fort sur GET show + champ documentHash (index/show/export/upsert).
- Tags libres bornés : 24 max, 64 chars, erreur invalid_tag (forbidden_tag supprimé) ; les 9 canoniques alimentent seuls les filtres ; round-trip export intact.
- updated_since ISO 8601 sur liste+export ; malformé → 400 invalid_updated_since ; vide → ignoré.
- Doc /api-docs : 5 nullable corrigés en type-array 3.1, traduction EN intégrale, PUT uuid-only documenté, enum codes à jour ; zcx_format.md §5 chiffré à 64 (fichier non tracké).
- Fix intégration : DiscordBot::SaveBuild adapté au nouveau champ Result.

Vérifié : suite complète 253 runs (seules les 3 failures scrims préexistantes sur main), rswag 20/20, YAML sans nullable/forbidden_tag.

Écart assumé vs spec : `updated_since=` vide → ignoré plutôt que 400 (rswag émet des vides ; un vide signifie « pas de filtre »). Spec design mise à jour.

Reste : réponse à Philippe (point 1 auteur déjà livré par 7d114fd1, à déployer).

---

# Investigation « builds équipe 2 identiques à l'équipe 1 » (/matches/:id)

## Statut : ENQUÊTE TERMINÉE — corruption de données, pas un bug de rendu

## Constats

1. **Le rendu est correct.** Nouveau test `show renders distinct builds for second team when served from cache`
   (matches_controller_test) : deux équipes avec builds distincts → sections distinctes, y compris via le chemin
   `Rails.cache.fetch` marshalé. Échantillon de ~130 pages de prod : les équipes sont bien distinctes partout.
2. **Le match signalé** (`2026-1-mat-3e1892c2…`, LaG vs Bad Drauf, id 1360) : les codes template des 16 joueurs
   (popovers) montrent T2 = T1 exactement (6/8 codes identiques octet pour octet, 8/8 ensembles de skills identiques).
3. **Preuve d'impossibilité in-game** dans le même lot : p.ex. « fist vs Bad Drauf » — un Elementalist/Necromancer
   (code décodé prim=6 sec=4) porte une barre 100% Dervish (Avatar of Lyssa, Mirage Cloak, Aura Slicer…) ;
   ailleurs Warrior/Assassin avec du Fire Magic élémentaliste. Physiquement impossible ⇒ données corrompues.
4. **Périmètre** : tournoi `2026-1-mat` — 46 matchs sur 50 scannés contiennent des combos prof↔skills impossibles ;
   les 5 matchs sans section stats (`json` vide) appartiennent tous à ce tournoi. Aucun autre tournoi affecté
   (miroirs ≤ 4/8 = méta copiée légitime, builds internes cohérents).
5. **Origine** : ce lot a été importé hors du code actuel. `Match.import!` (depuis 331630c6, 20/02/2026) stocke
   toujours `match.json` ou échoue ; ces matchs (joués le 17/01/2026) ont `json` vide ⇒ import one-off antérieur
   au code versionné, qui a dupliqué/mélangé les barres entre les deux parties.

## Reste à faire (décision produit)

- [ ] Récupérer les fichiers sources Tolkano/observer du mAT janvier 2026 et ré-importer les ~50 matchs du tournoi
      (les données actuelles ne permettent pas de reconstruire les vraies builds).
- [ ] À défaut : supprimer les matchs du tournoi 2026-1-mat ou masquer leurs builds.
- [ ] Optionnel : garde-fou à l'import dans `Match.import!` (cohérence skill↔profession) — d'abord fiabiliser
      `Skill.profession_id` en base locale (Jagged Strike=Ritualist ?! snapshot dev obsolète ; la prod semble saine).

---

# Fix API « visibility=public / visibility=all ne filtrent rien » (GET /api/v1/teambuilds)

## Statut : TERMINÉ

## Cause racine

`filtered()` dans `app/controllers/api/v1/teambuilds_controller.rb` ne traitait que
`visibility=mine` ; `public` et `all` étaient ignorés silencieusement → la relation de base
`Teambuild.visible_to(@player)` (publics + les siens) était renvoyée telle quelle, avec un 200.
Pas de fuite de données : les privés d'autrui n'étaient jamais exposés.

## Correctif

- `visibility=public` → scope `publicly_visible` ; `all`/nil/inconnu → défaut (tout le visible),
  convention tolérante du contrôleur (comme `status`/`sort`). 2 lignes ajoutées.
- Contrat Swagger mis à jour (enum `all|mine|public` + description), YAML régénéré via
  `rake rswag:specs:swaggerize`.
- 3 nouveaux exemples rswag (public/all/mine) ; l'exemple générique 200 déplacé en dernier
  (rswag : la dernière réponse 200 définie écrase la description documentée).

## Vérification

- rswag 23 exemples : les 4 cas visibility verts ; ne restent que 2 échecs delete préexistants
  sur main (instables selon l'ordre d'exécution — isolation de données entre exemples, à traiter à part).
- Minitest 275 runs / 3 failures = échecs Scrims préexistants documentés, non liés.

---

# Redesign « /builds/:id en lignes compactes style match » + popover template partagé

## Statut : TERMINÉ — fusionné sur main (ca37f2f9)

- Spec : docs/superpowers/specs/2026-08-25-build-show-redesign-design.md
- Plan : docs/superpowers/plans/2026-08-25-build-show-redesign.md
- 14 commits (branche build-show-redesign, travail en worktree, revue spec + qualité par tâche)

## Livré

1. `Gw1::TemplateCode` (app/services/gw1/template_code.rb) : encodeur GW complet AVEC attributs,
   vecteurs dorés vérifiés contre le format wiki + décodeur réel `GW::TemplateReader`.
   `TeamPlayer#template_code` délègue désormais (codes plus courts, même décodage).
2. Popover riche click-to-open (`template-code-popover` stimulus + partial partagé) rendu par
   /builds/:id ET /matches/:id ; copie presse-papiers avec fallback sélection ; position fixed
   (échappe aux `overflow-x-auto`) ; a11y aria-expanded + refocus Escape.
3. /builds/:id : tableau plein largeur d'une ligne par personnage (nom, badge assignment, chips
   profs, skills 4+4 32px, pills attributs, note italique). Cartes supprimées.
4. Tests : encodeur (vecteurs wiki), builds show (lignes, popover, cas sans profs), match show
   (popover ×2 + garde anti-fuite igname anonyme).

## Revue finale

READY TO MERGE — aucun blocant. Notes polish pour plus tard :
- Dépôt npm mort `@stimulus-components/popover` (package.json) → `yarn remove` possible.
- Popover : position recalculée seulement à l'ouverture (scroll pendant ouvert = décalé).
- `TeamPlayer#template_code` peut lever ArgumentError sur données pathologiques (côté builds
  secouru vers nil ; côté matches non, mais inatteignable en pratique).

---

# Fix : ordre des skills instable sur /matches/:id (« mauvais skills »)

## Statut : EN COURS

## Cause racine (prouvée)

`TeamPlayer#html_skills` (app/models/team_player.rb:98) attribue les slots de la barre de
build en itérant `team_player_skills.includes(...)` SANS `ORDER BY` → l'ordre retourné par
PostgreSQL (heap) change après les UPDATE, et la méthode réécrit `position` en base À CHAQUE
rendu de vue. Combiné au fragment cache `<% cache @match do %>` : chaque re-render fige un
ordre différent. Preuves : 3 timestamps de mutation distincts (11:21/11:23/11:28) avec des
positions différentes ; HTML servi ≠ état DB ; builds identiques affichés dans des ordres
différents (rangées 2 vs 9 du match f6c20e0c).

- [x] Test régression : ordre déterministe (elite→1, primaires par id, secondaire après,
      rez→8) + stabilité après churn heap (touch) + tie-break sur doublons de position
- [x] Fix : réécriture de `html_skills` (partition déterministe en mémoire, écriture compacte
      unique 1..n via `build_bar_ordered_skills`) ; tie-break `position: :asc, id: :asc` sur
      html_skills_simple et template_code
- [x] Tests minitest verts (3 runs / 4 assertions) ; suite models+controllers : 130 runs,
      seuls les 3 échecs Scrims préexistants documentés (prouvés par stash)
- [x] Preuve HTTP : 3 rendus consécutifs (cache purgé par redémarrage) → md5 des ordres
      identiques ; builds identiques → affichages identiques ; positions DB compactes 1..8

## Cause racine complétée (trace UPDATE instrumentée)

L'ancien algorithme avait 4 défauts cumulés : (1) itération sans ORDER BY → dépendante du
heap PG ; (2) position temporaire assignée en boucle 1 PUIS écrasée par les buckets
secondaire/autre — l'élite perdait son slot 1 si hors profession primaire, le rez son slot 8 ;
(3) `i += 1` inconditionnel cumulant des trous à chaque rendu → gonflement non borné des
positions (valeurs 10/11 observées) ; (4) écritures en base pendant le rendu + fragment cache
= chaque re-render figeait un ordre différent.

## Incidents de session

- Une autre session a mergé `feature/team-build-tags` DANS ce worktree pendant le travail :
  mes premières éditions du modèle ont été écrasées (fichier restauré à 13:43). Détection via
  md5 avant/après runs + `git log` (branche passée de « à jour » à « +10 commits »).
  Le correctif a été ré-appliqué et vérifié stable ensuite.
- Mes runners de diagnostic ont pollué le match de dév (2 faux team_players + un match
  orphelin sans imported_at/json) — nettoyés (`TeamPlayer.where(igname: nil)` ciblé + match
  orphelin détruit après vérification qu'il s'agissait bien d'un artefact).

---

# Fix 2 : skills mal nommés (« Life Siphon » sur un Mesmer) + placeholder transparent

## Statut : TERMINÉ — non commité

## Cause racine

`data/code_skills.txt` contient un bloc ~1000+ au numérotage fictif (ordre wiki, pas game IDs)
→ `skills:import` a créé 118 lignes fausses. L'observer émet de VRAIS game IDs
(gw-skilldata : 1043=Dash/Assassin/Factions), donc `find_by(skill_id:)` tombait sur les
lignes au nom faux → affichage impossible en jeu (ex. Necro skill sur Mesmer/Assassin).

## Livré

- [x] `skills:repair_from_source` (rake, idempotent) : supprime les skill_id absents du jeu
      après re-pointement défensif, renomme vers desc.json — 68 renommées, 50 supprimées,
      audit final : 0 mismatch / 1514
- [x] Enrichissements relancés (import_informations, update_for_template_codes nil-safé,
      update_campaigns) ; icônes des noms corrigés présentes dans les assets
- [x] Placeholder inconnu : `transparent.png` 64×64 RGBA généré, utilisé par html_skills et
      html_skills_simple (le slot reste hoverable « Unknown », layout inchangé)

## Vérification

- Match c9a50317 Character #12 (Mesmer/Assassin) : Dash remplace Life Siphon ✓ ;
  Necro/Assassin : Life Siphon (109) + Dash légitimes ✓
- Rendus frais vs cache : ordres identiques ; rangée 7 skills = 8 slots dont 1 transparent
- Tests : team_player_test 3/3 vert ; suite 130 runs = seuls les 3 échecs Scrims préexistants

---

# Remove "Cyril" from files + git history (HISTORY REWRITE — DESTRUCTIVE)

## Statut : TERMINÉ (local-only) — mirror réécrit vérifié dans `/tmp/gwrank-mirror`, AUCUN push effectué, workdir intact

I'm using the writing-plans skill to create the implementation plan (location overridden to `tasks/todo.md` per AGENTS.md).

**Goal:** Zero `\bCyril\b` in working tree + all branches/tags history. `Cyrillic` in `config/initializers/friendly_id.rb:99` must survive.

**État mesuré:**
- Worktree: 37 vrais hits dans 4 fichiers test (`save_build_test.rb:19`, `team_build_commands_test.rb` x18, `build_commands_test.rb` x10, `player_commands_test.rb` x8) + 1 faux positif `Cyrillic`.
- Historique: 17 commits touchés par `-S "Cyril"` (ex. `0008f958`, `fffd9e1e`, `4e757086`, `bfa12b42`, `a78571cc`), 806 commits au total, branches `main`, `social`, `feat/*`, `chore/2026-update`, remotes `origin` + `dokku`.
- Outil: `git filter-repo` NON installé — à installer avant.

**Approche:** mirror clone frais dans `/tmp`, `filter-repo --replace-text` avec regex `\bCyril\b`, vérification, force-push, re-clone workdir. Jamais de rewrite in-place dans `/home/arka/Work/gwrank` (risque de perte + merge concurrent vu le 2026-08-26). `filter-branch` exclu (déprécié).

- [x] Step 0 — Validation utilisateur (BLOQUANT): remplacement (défaut `TestUser`), périmètre push (`origin` seul vs `origin`+`dokku`), confirmation backup OK
  → Reçu: `TestPlayer` + local-only (aucun push).
- [x] Step 1 — Backup + prérequis: `cp -a` ou `git clone --mirror` de sécu, `pipx install git-filter-repo`, `git status` propre (stash si besoin)
  → Backup: `/tmp/gwrank-backup-mirror` (81M, pré-rewrite). `git-filter-repo` via `~/.local/bin/git-filter-repo` (pacman/sudo indisponibles).
- [x] Step 2 — Rewrite isolé: `git clone --mirror <origin> /tmp/gwrank-mirror`, `echo 'regex:\bCyril\b==>TestUser' > /tmp/replace.txt`, `git filter-repo --replace-text /tmp/replace.txt --force`
  → Fait avec `regex:\bCyril\b==>TestPlayer`, 806 commits réécrits en ~5s. Remote `origin` stripped par filter-repo (attendu).
- [x] Step 3 — Vérification (BLOQUANT): `git log --all -S Cyril` vide, `git rev-list --all | xargs git grep -w Cyril` vide, `rg -w Cyril` vide hors `Cyrillic`, `bin/rails test test/services/discord_bot/` vert
  → `grep -w Cyril` sur les 806 revs: vide ✓ ; `TestPlayer` sur main: 37 hits (remplacement 1:1) ✓ ; `Cyrillic` préservé (friendly_id.rb:99) ✓ ; `log -S Cyril` ne liste plus que 3 commits introducteurs de `Cyrillic`/fonts binaires (4e757086, bfa12b42, a78571cc) ✓ ; `ruby -c` OK sur les 4 fichiers test ✓. Suite rails NON lancée (socket docker inaccessible) — à lancer après resync.
- [ ] Step 4 — Push forcé + resync (VOLONTAIREMENT NON EXÉCUTÉ — choix local-only): voir commandes ci-dessous.

**Pour pousser manuellement depuis le mirror vérifié:**
```bash
cd /tmp/gwrank-mirror
git remote add origin git@github.com:gwrank/gwrank.git
git push --force --all origin && git push --force --tags origin
# optionnel: git remote add dokku dokku@83.228.226.119:gwrank && git push --force --all dokku
cd /home/arka/Work/gwrank && git fetch origin && git reset --hard origin/main  # + re-clone pour chaque collaborateur
```

**Réserve substring:** `Cyril` en sous-chaîne subsiste dans `Cyrillic` (voulu) et dans les blobs binaires de fonts `SourceCodePro-*.otf/ttf` (métadonnées, remplacement = corruption — déconseillé).

**Risques:** réécriture des 806 SHAs, PRs/forks cassés, déploiements `dokku` à refaire, collaborateurs doivent re-cloner. Rollback = backup `/tmp` + reflog remote (si protégé).

---

# Fix crash /mat schedule — Validation failed: Discord server taken + Timezone blank

## Statut : EN COURS (approved: full fix)

## Cause racine (prouvée, Phase 1-2 systematic-debugging)

- `AutomatedTournamentSchedule` a un index unique + validation sur `discord_server_id` SEUL (1 ligne/serveur, époque daily-only).
- Le support monthly (`is_monthly`, migration 20260724000001) n'a ni scopé l'unicité ni rendu `timezone` optionnel (`timezone NOT NULL` + `validates presence`).
- `MatCommands#handle_schedule` (mat_commands.rb:62) fait `find_or_initialize_by(discord_server_id:, is_monthly: true)` SANS timezone → sur un serveur ayant déjà un schedule daily : `find` rate (is_monthly mismatch), `save!` tente une 2e ligne même `discord_server_id` + `timezone=nil` → exactement les 2 erreurs du log.

## Hypothèse (Phase 3)

Scoper l'unicité à `[discord_server_id, is_monthly]`, rendre `timezone` requis sauf monthly, et scoper toutes les lectures daily à `is_monthly: false` permet la coexistence daily+monthly sans régression.

## Revue (post-implémentation)

**Vérification :** RED d'abord — 15 runs / 2 failures + 3 errors reproduisant exactement le crash prod (`Discord server has already been taken, Timezone can't be blank`, mat_commands.rb:69). GREEN ensuite — 39 runs ciblés (schedule, registration, mat/at commands, reminder check) 0 échec ; `test/models + test/services` 249 runs 0 échec ; `ruby -c` OK sur les 7 fichiers touchés.
Bonus trouvés en chemin (inclus car bloquants pour la même feature) : `next_monthly_occurrence` comparait `Time <= Date` (ArgumentError au premier appel réel) et retournait une `Date` (casse `>`/`strftime %H:%M`) → retourne désormais `Time.utc` ; `previous_occurrence` exigeait un timezone via `occurrence_on` → branché monthly ; `current_for_server` fenêtrait le monthly sur la fenêtre daily (queue monthly toujours vide sans schedule daily) → nouveau `current_monthly_for_server` + `monthly_window_bounds`.

**Décisions :** occurrences monthly à minuit UTC (`MONTHLY_OCCURRENCE_HOUR_UTC = 0`, 1 ligne à ajuster quand l'heure réelle est confirmée) ; `current_for_server` est désormais daily-only (les appelants monthly utilisent `current_monthly_for_server`) ; boutons register/unregister inchangés (`Player#current_mat_registration` reste non-fenêtré).
**Env :** pas de PG local ni accès docker → provisionné Postgres 16 via mise dans `/tmp/gwrank-pgdata` (socket `/tmp/gwrank-pgsock`, port 5433) + `bundle install` ; à arrêter/supprimer après usage (`pg_ctl -D /tmp/gwrank-pgdata stop`). Non commité, en attente de revue.

## Plan (TDD: test d'abord, un seul fix)

- [ ] RED : tests qui échouent (model coexistence daily+monthly même serveur ; monthly sans timezone valide ; doublon daily/monthly invalide ; `MatCommands#handle_schedule` crée la ligne monthly en gardant la daily ; `AtCommands` retrouve la daily quand la monthly existe)
- [ ] Migration : backfill `is_monthly` NULL→false + NOT NULL default false ; `timezone` NULL autorisé ; supprime l'index unique `discord_server_id`, ajoute unique `[discord_server_id, is_monthly]`
- [ ] Modèle : `uniqueness: { scope: :is_monthly }`, `timezone presence unless monthly`, scopes `daily`/`monthly` ; `next_monthly_occurrence` retourne un `Time.utc` (pas une `Date`, sinon `>`/`strftime %H:%M` cassent) ; `previous_occurrence` branché monthly (mois précédent, pas `occurrence_on` qui exige un timezone)
- [ ] Scope daily : `AtCommands` (schedule/next/join/players/require_schedule!), `AutomatedTournamentRegistration.window_bounds` (schedule daily), `AtReminderCheck` (daily only)
- [ ] Fenêtre monthly : `current_for_server` actuel est fenêtré daily → ajouter `current_monthly_for_server` + `monthly_window_bounds` (basés schedule monthly, `[prev+2h, next+2h]`) et basculer `MatCommands` (players/panel) dessus ; `Player#current_mat_registration` reste non-fenêtré (boutons)
- [ ] GREEN/verify : repro tests verts + suite existante (`automated_tournament_*`, `at_commands`) ; `ruby -c` systématique

## Hors périmètre

- Heure exacte du mAT (on cale à 15:00 UTC, même que slot B ? à trancher : minuit UTC vs heure réelle) — documented, ajustable en 1 ligne.
- Normalisation `.to_s` des snowflakes : non nécessaire (l'unicité a matché, donc le cast marche) — on ne touche pas.

---

# Fix spam @here MAT reminder (7x "Monthly AT is in 24 hours")

## Statut : EN COURS

## Cause racine (Phase 1-2 systematic-debugging, prouvée par lecture)

- `MatReminderCheck#check_and_remind` (mat_reminder_check.rb:29) : condition
  `now >= next_occ - 24h && now <= next_occ` vraie pendant 24h entières,
  poll toutes les 60s (`POLL_INTERVAL`, command_bot_job.rb:50) → ~1440
  `@here` par schedule. Même défaut sur le rappel registration
  (`now >= registration_start - 1h && now <= registration_start` → ~60 envois).
- Aucune déduplication, contrairement au modèle qui marche :
  `AtReminderCheck` (at_reminder_check.rb:24-32) = fenêtre étroite
  `[trigger_start, trigger_start + POLL_INTERVAL)` + garde
  `last_reminded_on == next_occ.to_date`.
- 7 messages identiques = 7 polls consécutifs dans la fenêtre (ou N schedules
  monthly vers le même channel, même boucle `find_each` sans rescue).

## Hypothèse (Phase 3)

Miroir du pattern `AtReminderCheck` : fenêtre étroite + garde DB par occurrence
supprime le spam tout en garantissant 1 envoi.

## Plan (TDD)

- [x] RED : `test/services/discord_bot/mat_reminder_check_test.rb` — 2 appels
      dans la fenêtre 24h → 1 seul message ; hors fenêtre → 0 ; registration idem
- [x] Migration : `last_registration_reminded_for :date` sur
      `automated_tournament_schedules` (`last_reminded_on` réutilisé pour le
      rappel 24h, lignes daily/monthly isolées par scope unique)
- [x] Fix `MatReminderCheck` : fenêtres étroites + gardes + `update!` + rescue
      par schedule (un schedule pourri ne bloque plus les autres)
- [x] Reset des 2 gardes dans `MatCommands#handle_schedule` si pattern changé
      (miroir `AtCommands` timezone_changed)
- [x] GREEN/verify : repro verts + `automated_tournament_*`, `at/mat_commands`,
      `at/mat_reminder` ; `ruby -c` systématique

## Revue (post-implémentation)

**Vérification :** RED d'abord — 5 runs / 2 failures reproduisant exactement le
spam (7 polls → 7 `@here`). GREEN ensuite — `mat_reminder_check` 5/5 ;
`discord_bot/` + `automated_tournament_*` 99 runs 0 échec ; suite complète
338 runs, seules les 3 failures `ScrimsControllerTest` préexistantes sur main
(redirect sign_in, sans rapport) ; `ruby -c` OK sur les 4 fichiers.
**Décisions :** `last_reminded_on` réutilisé pour le rappel 24h monthly
(isolation par ligne daily/monthly) + nouvelle colonne date pour le rappel
registration (même date d'événement, sinon collision) ; fenêtre = `POLL_INTERVAL`
comme `AtReminderCheck` ; envoi raté → pas de marquage (retry au prochain poll).
