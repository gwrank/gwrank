
## 2026-08-24 — Worktree + bin/yarn wrapper
- Le PATH expose `bin/yarn` du repo principal (wrapper Rails avec `Dir.chdir(APP_ROOT)`). Dans un worktree, tout appel `yarn` s'exécute silencieusement dans main et y écrit les builds.
- Règle : dans un worktree, toujours invoquer yarn par chemin absolu (`~/.local/share/mise/installs/node/26.5.0/bin/yarn`). Vérifier `which yarn` avant toute commande node dans un worktree.
