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
