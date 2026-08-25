
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
