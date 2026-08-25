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
