# Design — Retours Z-Codex v3 (API teambuilds)

**Date :** 25/08/2026
**Source :** `docs/gwrank_api_retours.md` (Philippe, Z-Codex) — 5 points retenus.
**Décisions validées avec Arka le 25/08/2026.**

## Contexte

Z-Codex utilise déjà `GET /api/v1/teambuilds/export` en production (lot 3). Cinq demandes
restent à traiter : auteur, garde anti-écrasement (`If-Match`), tags libres, synchro
incrémentale (`updated_since`), et corrections documentaires.

Constat clé à l'exploration : le **point 1 est déjà réglé** — le commit `7d114fd1` (24/08)
expose `author: username` dans list/export/show/upsert et la spec OpenAPI le documente
(`spec/swagger_helper.rb:97`). Philippe a testé avant ce commit ; il ne manque que le
déploiement et une réponse.

## Décisions

| # | Demande | Décision |
|---|---|---|
| 1 | Champ auteur | `author: username` seul suffit (déjà livré). Pas de `owner.id`, pas d'`isMine`. |
| 2 | If-Match / 412 sur PUT | Garde **optionnel**, basé sur le hash de document existant. Rétrocompatible. |
| 3 | Tags hors liste fermée | **Tags libres acceptés** (strings bornés). Les 9 valeurs canoniques seules alimentent les filtres. |
| 4 | `updated_since` | Sur la liste **et** `/export`. ISO 8601 strict, invalide → 400. |
| 5 | Doc OpenAPI | `max_depth = 64` chiffré, 5 `nullable` corrigés en type-array 3.1, doc `/api-docs` traduite **entièrement en anglais**. |

---

## B. If-Match / 412 sur le PUT (priorité 1 — perte de données)

### Principe

L'ETag applicatif est le `document_hash` SHA-256 canonique déjà calculé par
`Teambuilds::DocumentHash` (hash du document hors `updatedAt`) et stocké en DB. Z-Codex
connaît déjà cet algorithme : il s'en sert pour le no-op d'upsert. Aucune nouvelle colonne,
aucun compteur à maintenir.

Simplification par rapport au design oral : le header `ETag` porte le hash hex nu entre
quotes (`ETag: "fa923f7a…"`) — **sans préfixe `sha256:`** — pour que la valeur soit
identique au champ body `documentHash` que les clients comparent directement.

### Changements

1. **`Teambuild#summary`** ajoute `documentHash: document_hash` (donc présent dans index,
   show, upsert et export).
2. **`GET /{id}`** pose un ETag fort manuellement :
   `response.set_header("ETag", %("#{teambuild.document_hash}"))` — on n'utilise pas
   `fresh_when`, qui produirait un ETag faible combiné incompatible avec la comparaison.
3. **PUT** lit le header `If-Match` :
   - parsing tolérant : quotes optionnelles, valeur `*` acceptée (= « doit exister ») ;
   - ordre d'exécution : résolution source_uuid → parse JSON → find → **check If-Match
     contre le hash courant** → no-op ou replace ;
   - build existant + hash ≠ `If-Match` → **412** `{errors: [{code: "precondition_failed",
     path: "$", message: "…"}]}` (format erreurs existant) ;
   - build inexistant + `If-Match` présent → **412** également (pas de création
     conditionnelle) ;
   - `If-Match` absent ou match → comportement actuel inchangé (dernier-gagne, no-op sur
     hash identique).

### Non-inclus

Pas d'`If-Match` sur DELETE ni d'obligation (428) : rétrocompatibilité totale, Z-Codex
l'adopte à son rythme.

---

## C. Tags libres (priorité 2 côté communauté)

### Validation (`Teambuilds::Validator`)

`validate_tags` ne consulte plus `ALLOWED_TAGS` pour rejeter. Nouvelle validation
structurelle uniquement :

- `tags` doit être un array de strings non vides (après strip) ;
- chaque tag ≤ **64 caractères** (`TAG_MAX_LENGTH = 64`) ;
- au maximum **24 tags** (`MAX_TAGS = 24`) ;
- toute violation → erreur **`invalid_tag`** sur `$.tags[i]` — nouveau code qui remplace
  `forbidden_tag` dans l'émission **et** dans l'enum des codes documentés.

### Stockage (`Teambuilds::Indexer`)

`canonical_tags` conserve son comportement actuel pour les 9 valeurs reconnues
(insensible à la casse → forme canonique) ; tout autre tag valide est stocké tel quel,
dédupliqué. La colonne `tags varchar[]` existante suffit — aucune migration.

### Filtres et round-trip

- Le scope `tagged_with_any` reste une intersection exacte : filtrer `tags=GvG` ne remonte
  que les builds porteurs du canonique `GvG`, jamais des tags libres.
- `/export` renvoie tous les tags stockés → un aller-retour Z-Codex préserve ses tags
  locaux (« meta », noms de guilde…), conforme au §4 de `zcx_format.md`.

---

## D. `updated_since`

- Scope `with_updated_since(time)` dans `Teambuild` (`where(updated_at: time..)`),
  branché dans `filtered` → disponible automatiquement sur `GET /teambuilds`
  **et** `GET /teambuilds/export`.
- Parsing strict `Time.iso8601`. Paramètre **absent ou vide** → pas de filtre ; paramètre
  **présent et malformé** → **400** `{errors: [{code: "invalid_updated_since",
  …}]}` (cohérent avec `invalid_source_uuid`, répond au principe « contrat vérifiable »
  du §5.1 des retours). *(Ajusté pendant l'implémentation : rswag émet `updated_since=`
  vide dans ses exemples, et un vide explicite signifie bénignement « pas de filtre » ;
  seul le malformé est rejeté.)*
- Date future acceptée (résultat vide) — pas de cas particulier.

---

## E. Documentation OpenAPI (`/api-docs`)

Tout passe par la **source rswag** (`spec/swagger_helper.rb` +
`spec/requests/api/v1/teambuilds_spec.rb`), puis régénération de
`docs/openapi/teambuilds.yaml` via `rswag:specs:swaggerize` :

1. **Traduction intégrale en anglais** de toutes les descriptions, summaries et messages
   du document servi sur `/api-docs` (aujourd'hui en français).
2. Les 5 `nullable: true` → `type: [integer, "null"]` / `[string, "null"]` /
   `[object, "null"]` (lignes 84-88 et 198 de `swagger_helper.rb`).
3. `max_depth` : description du code d'erreur documentant la limite réelle (**64**) avec
   sa sémantique exacte telle qu'implémentée (`validator.rb`, `MAX_DEPTH = 64`) : chaque
   personnage racine est à la profondeur 0, ses variantes imbriquées incrémentent, et tout
   nœud de profondeur > 64 rejette le document en 422 `max_depth`. Une chaîne linéaire
   compte donc au maximum 1 + 64 nœuds.
4. Nouveaux éléments : champ `documentHash` dans `TeambuildSummary`, paramètre query
   `updatedSince`, code 412 avec `precondition_failed`, remplacement de `forbidden_tag`
   par `invalid_tag`, réponse 400 `invalid_updated_since`.
5. Description du PUT précisée : **source_uuid uniquement** (l'id serveur est refusé) —
   demande 9 de Philippe, gratuite.

Note : la doc rswag étant test+doc simultanés, chaque changement de spec s'accompagne de
la request-spec correspondante (section Tests).

Par ailleurs, `docs/zcx_format.md` §5 (« récursif sans limite ») est corrigé pour porter
le chiffre 64.

---

## Tests

Minitest (`test/controllers/api/v1/teambuilds_controller_test.rb`,
`test/services/teambuilds/{validator,indexer}_test.rb`) :

- **If-Match** : 200 no-op quand match ; 412 mismatch sur existant ; 412 sur inexistant ;
  sans If-Match → replace comme avant ; `*` sur existant → OK ; quotes tolérées.
- **Tags** : tags libres acceptés et restitués par summary/export ; canonisation mixte
  (`gvg` + `meta` → `["GvG", "meta"]`) ; `invalid_tag` sur non-string, vide, > 64 chars,
  > 24 tags ; filtre `tags=GvG` ignore les libres.
- **updated_since** : filtre efficace sur index et export ; 400 sur date invalide.
- **documentHash** : présent dans index/show/export/upsert.

rswag (`spec/requests/api/v1/teambuilds_spec.rb`) : specs correspondantes pour 412 et
400, exemples mis à jour, descriptions en anglais → YAML régénéré cohérent.

Vérification finale : suites minitest + rspec vertes, `docs/openapi/teambuilds.yaml`
valide en 3.1 (plus aucun `nullable:`).

## Hors périmètre (explicitement)

- `visibility=public|all` (demande 1 de la v1) — non retenue aujourd'hui.
- Pagination d'/export, rejet global des paramètres inconnus (demande 7),
  consultation publique sans compte (demande 8), alignement enum `gameMode` (demande 10),
  verrou obligatoire (428), `If-Match` sur DELETE.
