# Lessons

## Session 2026-08-21 (Redis → Solid trio)

1. **Dispatch subagents as standalone tool calls.** Pairing a `task` dispatch with another tool call (todowrite/edit) in one message lost the task result twice (Task 3, Task 7) — git state confirmed no work had happened. Rule: never batch a subagent dispatch with any other call; verify HEAD advanced if a result looks missing.

2. **Validate plan snippets against installed gem versions before writing them as "expected".** Two plan details were stale/invalid and cost implementer detours: (a) assumed `ApplicationJob` had a no-op `perform` (it doesn't — smoke target failed); (b) wrote `<%= 100.ms %>` / old cable schema for solid_cable 4.x (`.ms` doesn't exist in ActiveSupport; v4 adds `channel_hash`). Rule: when planning gem-specific config, fetch the actual template from the bundled gem or mark snippets as illustrative-with-verify-step.

3. **ERB in YAML configs produces Ruby objects, not strings.** `message_retention: <%= 1.day %>` became Integer 86400 and broke solid_cable's `parse_duration` (expects `"1.day"` string form). Rule: durations in gem-parsed YAML go in as plain scalars (`0.1.seconds`, `1.day`); reserve ERB tags for values you actually want evaluated.

## Session 2026-08-24 (Refonte UI /builds)

4. **En revue visuelle, montre la version littérale de ce qui est demandé, pas une interprétation « améliorée ».** L'utilisateur voulait les 8 icônes de professions ; le plan a spécifié 6 + "+N" (choix non sollicité) → correction. Rule: quand un retour décrit un affichage précis (nombre d'éléments, libellés), reproduire exactement ; proposer des variantes en question, pas en implémentation.

5. **Vérifier l'interface réelle des services avant d'écrire des scripts** (`Result.ok?` vs `success?`, Data.define). Coût : 2 allers-retours. Rule: `grep "def \|Data.define" service.rb` avant tout script appelant.

6. **Un `network_error` de dispatch ne signifie pas « non exécuté ».** Un subagent au destinataire perdu avait commité son travail avant que la réponse ne se perde ; ma ré-exécution manuelle créait un doublon (test défini deux fois). Rule : après tout dispatch en échec réseau, inspecter `git status` + `git log` AVANT de refaire le travail.

## 2026-08-24 — Worktree + bin/yarn wrapper
- Le PATH expose `bin/yarn` du repo principal (wrapper Rails avec `Dir.chdir(APP_ROOT)`). Dans un worktree, tout appel `yarn` s'exécute silencieusement dans main et y écrit les builds.
- Règle : dans un worktree, toujours invoquer yarn par chemin absolu (`~/.local/share/mise/installs/node/26.5.0/bin/yarn`). Vérifier `which yarn` avant toute commande node dans un worktree.

## 2026-08-24 — Minitest n'exécute pas test/system par défaut
- `bin/rails test` ignore `test/system/*` ; les lancer explicitement (`bin/rails test test/system/...`) dans chaque étape de vérification.

## 2026-08-25 — La revue de code ne remplace pas la vérification visuelle
- Deux régressions UI passées les revues : modificateur `gw-btn--ghost` sans sa classe de base (rendu = lien nu) et `series_nav(:bootstrap)` de Pagy dont le `ul.pagination>li>a` devient une pile verticale sans Bootstrap.
- Règles : (1) jamais un modificateur BEM sans sa base ; (2) pour tout composant tiers rendu dans les vues (Pagy…), vérifier le HTML réel généré et neutraliser sa structure imbriquée en CSS ; (3) les étapes de vérification des tâches UI doivent inclure un rendu réel (smoke request + inspection du markup), pas seulement des greps de classes.

## 2026-08-25 — Deuxième piège de worktree : binstubs bundle/rails
- Comme bin/yarn, `bundle` résout via PATH vers le binstub du repo principal (Dir.chdir APP_ROOT). Dans un worktree : `./bin/bundle`, `./bin/rails`, yarn par chemin absolu.
- Règle : dans un worktree, TOUTE commande outil passe par le binstub relatif `./bin/…` ou un chemin absolu ; jamais un binaire nu résolu par PATH.

## 2026-08-25 — git add -A avale les fichiers en cours de debug
- Un `git add -A` a commité un logger de diagnostic temporaire dans un commit de polish sans rapport.
- Règle : commits toujours par fichiers ciblés (`git add <chemins>`) dès qu'un fichier hors périmètre est modifié dans le worktree ; `git status` avant chaque commit.

## 2026-08-25 — Copie marketing paraphrasée depuis la doc = corrections factuelles
- La copie de la landing page Z-Codex, résumée depuis le README du projet, a été corrigée par l'utilisateur : « 8 personnages » → 8 à 12 ; arbre de variantes à profondeur illimitée (pas juste « organized in trees ») ; « spike calculator » comme outil nommé ; sources communautaires élargies (GW1 builds, more to come) ; filtres du catalogue par Skill Type et surtout Mechanics omis.
- Règles : (1) toute affirmation produit visible par l'utilisateur se cite au plus près de la source ou se fait valider mot pour mot AVANT commit — ne jamais paraphraser de mémoire ; (2) en cas de doute sur un terme utilisateur (« pike » → spike), le dire explicitement dans le résumé plutôt que d'assumer en silence ; (3) les listes de capacités (« filterable catalog ») doivent reprendre LES critères nommés par la doc/source, pas un générique.
- Complément du jour : ne pas fusionner deux features distinctes en une seule formule (« the ten conditions of the monthly flux cycle ») — garder les concepts séparés comme dans la source, et laisser la liste ouverte (« … and much more! ») quand le produit couvre plus que l'énumération.

## 2026-08-26 — Environnement tests & preuves HTTP

- PostgreSQL tourne uniquement via docker (`docker start <projet>-db-1`, port 5432, postgres/postgres). Sans `DATABASE_HOST=localhost DATABASE_USER=postgres DATABASE_PASSWORD=postgres`, Rails tente les sockets et échoue. Règle : vérifier `docker ps` avant toute commande Rails ; préfixer systématiquement ces trois variables.
- Pour prouver un endpoint en local : serveur dev (`bin/rails server -p PORT` + curl) plutôt que `Rack::MockRequest` — ce dernier bute sur Host Authorization (403 HTML pour example.org) puis IPAddr quirks. Coût : 3 allers-retours perdus.

## 2026-08-26 — Compositions de variantes (worktree & assets)

- Un worktree neuf échoue massivement aux tests tant que les artefacts JS/CSS ne sont pas buildés (`app/assets/builds/*` est gitigné) : `application.js missing` en controller tests, Tailwind absent en system tests (navs dupliquées visibles). Règle : après création d'un worktree, lancer `yarn install && yarn build && yarn build:css` (chemin yarn absolu) AVANT la baseline, et s'attendre à un `build:css` silencieux qui produit zéro fichier si postcss n'a pas de node_modules.
- `Skill#html_image_simple` rescues `Propshaft::MissingAssetError` → `''` : une fixture skill sans image correspondante réduit le nombre d'imgs rendues et rend toute assertion `img[title=…]` impossible. Règle : chaque nouveau skill en fixture exige un JPEG placeholder dans `app/assets/images/skills/` au nom dérivé de `Skill#filename`.
- Les skills partagés entre fixtures et vrais builds (ex. 1011/919 dans gvg_split) : ajouter la fixture skill SANS son asset casse des tests préexistants — vérifier le croisement avant.

## 2026-08-26 — Éditions écrasées par un merge concurrent dans le même worktree

- Une autre session a mergé une branche DANS ce répertoire pendant que je travaillais : mes
  éditions non commitées de `team_player.rb` ont été restaurées à l'ancien état, et les tests
  « verts » observés venaient en réalité des changements de données de test, pas du modèle.
- Règles : (1) après chaque édition de fichier, vérifier la persistance (md5/grep) AVANT de
  conclure ; (2) refaire `git log`/`git status` si un comportement contredit le code lu —
  une branche « à jour » passée « +N commits » = travail concurrent ; (3) quand l'arithmétique
  des positions est impossible avec le source lu, douter du SOURCE EXÉCUTÉ (tracer
  `instance_method(:x).source_location`), pas seulement du fichier.

## 2026-08-26 — code_skills.txt : numérotage wiki ≠ game IDs

- Le bloc 1000+ de data/code_skills.txt est un numérotage de liste wiki, PAS les IDs jeu ;
  l'observer/GWCA émet les vrais game IDs (source de vérité : data/skills/desc.json +
  data.json de build-wars/gw-skilldata).
- Règles : (1) toute correspondance de skills se fait par skill_id validé contre
  gw-skilldata, jamais par nom ni par une liste maison non alignée ; (2) un doublon de nom
  avec deux game_ids différents = signal d'alarme immédiat ; (3) pour auditer :
  `rake skills:repair_from_source` (idempotent) puis recompter les mismatches.

## 2026-09-23 — shared room lifecycle review

8. **Preserve expiry as a distinct store error.** Deleting an expired snapshot and raising the
   generic `room_not_found` error loses the reason needed to notify existing subscribers. Rule:
   expiry-triggering operations must raise an identifiable error carrying `creator_timeout` or
   `max_lifetime`; unknown rooms must remain a separate path.

9. **Gate delivery before targeted disconnects.** A targeted replacement close is not complete
   when the websocket close is recorded if queued stream callbacks can still transmit afterward.
   Rule: acquire the existing delivery mutex, mark the stream closed, and clear pending messages
   before issuing the permanent close.
