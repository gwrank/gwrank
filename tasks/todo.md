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
