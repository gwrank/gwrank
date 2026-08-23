# Design — API teambuilds : export global, statut draft, indexation des variants, tags fermés

Date : 2026-08-23
Statut : Approuvé (design validé en session, voir historique de conversation)

## Contexte

L'API REST des teambuilds (`/api/v1/teambuilds`) couvre déjà : upsert idempotent
`PUT` par `(propriétaire, source_uuid)` avec `visibility=private|public`, recherche
paginée avec filtres, récupération et suppression unitaires, téléchargement web en
`.zcx`. Les documents zcx (JSON, spécification Z-Codex) sont stockés intacts en
jsonb ; les arbres de `variants` imbriqués sont déjà acceptés par le validateur.

Cette spec couvre les quatre besoins restants exprimés pour l'intégration Z-Codex :

1. Export global en un seul appel.
2. Statut dédié « Draft » indépendant de la visibilité.
3. Indexation des personnages situés dans les variants.
4. Liste fermée de tags imposée par l'API.

Hors périmètre : pagination de l'export, sync incrémental (`since=`), refonte du
champ `gameMode`, upload multipart de fichiers `.zcx`.

## 1. Export JSON global — `GET /api/v1/teambuilds/export`

Nouvelle action de collection dans `Api::V1::TeambuildsController`, même authentification
Bearer que le reste de l'API. Réponse unique, sans pagination :

```json
{
  "teambuilds": [
    {
      "id": 123,
      "sourceId": "uuid-zcodex",
      "name": "Split GvG",
      "tags": ["GvG"],
      "gameMode": "PvP",
      "status": "published",
      "visibility": "public",
      "playerCount": 8,
      "createdAt": "2026-08-23T10:00:00Z",
      "updatedAt": "2026-08-23T12:30:00Z",
      "document": { "version": 18, "...": "document zcx intégral, tel que stocké" }
    }
  ]
}
```

- Contenu : tous les teambuilds visibles par l'appelant (`Teambuild.visible_to(player)`),
  c'est-à-dire les publics + les siens, y compris les drafts publics — le champ
  `status` permet au client de filtrer s'il le souhaite.
- Z-Codex reconstruit localement ses fichiers `<sourceId>.zcx`.
- Arbitrage assumé : réponse unique sans pagination. À l'échelle d'une communauté
  GW1 la charge reste raisonnable ; on privilégie la simplicité du contrat « tout
  en un appel ». Un garde-fou éventuel (limite haute) pourra être ajouté plus tard
  si les volumes le justifient — pas maintenant (YAGNI).
- Export vide → `{"teambuilds": []}`.

## 2. Statut dédié `draft` / `published`

- Migration : `add_column :teambuilds, :status, :string, null: false, default: "published"`
  + index sur `status`. Les lignes existantes deviennent `published` (compatibilité arrière
  totale : aucun comportement visible ne change pour les clients actuels).
- Indépendance visibilité/statut (choix validé) : un build peut être `public` + `draft`
  — visible par tous, étiqueté brouillon. Aucune règle de masquage liée au statut ;
  la confidentialité reste portée par `visibility` seule.
- Envoi : paramètre query `status=draft|published` sur le `PUT /api/v1/teambuilds/:id`,
  symétrique du paramètre `visibility` existant. Absent → valeur conservée (`published`
  à la création). Comme pour la visibilité : un changement de statut est appliqué même
  si le document est identique, mais ne compte pas comme un changement de document
  (le flag `changed` de la réponse ne suit que le contenu du zcx).
- Modèle : constante `STATUSES = %w[draft published]`, validation d'inclusion, scopes
  `Teambuild.published` / `Teambuild.draft`.
- `status` ajouté au résumé (`Teambuild#summary`) ; filtre optionnel `status=` sur la
  recherche (`index`) et sur l'export.
- Web UI : badge « Draft » sur les vues builds concernées (index + show).

## 3. Indexation des personnages des variants

Choix validé : tout indexer (racine + variants), pour que les filtres profession /
elite skill / attribut matchent aussi les personnages alternatifs.

- `Teambuilds::Indexer` parcourt l'arbre complet en DFS pré-ordre (personnage, puis ses
  variants récursivement), même cap de profondeur que le validateur (64). Chaque
  personnage rencontré crée une ligne `teambuild_characters` avec position séquentielle
  continue (l'unicité `(teambuild_id, position)` est respectée par la numérotation).
- `player_count` reste calculé sur le niveau racine uniquement (validation 0–12 inchangée) ;
  les lignes issues des variants n'influencent pas ce compteur.
- Garde-fou déterministe : le validateur refuse tout document dont l'arbre aplati dépasse
  **512** personnages au total — nouveau code d'erreur `too_many_characters`. On préfère
  un rejet explicite à une troncature silencieuse.
- Les documents restent stockés tels quels : seule la dérivation de l'index change.

## 4. Tags : liste fermée imposée

- `Teambuild::ALLOWED_TAGS = %w[GvG HA RA TA AB FA JQ PvP PvE]`.
- Enforcement dans `Teambuilds::Validator` (point d'entrée unique des règles document,
  cohérent avec les erreurs 422 structurées existantes) :
  - chaque entrée de `tags` est comparée insensiblement à la casse à la liste autorisée ;
  - entrée inconnue → erreur `{path: "tags", code: "forbidden_tag"}` ;
  - les tags valides sont stockés sous leur forme canonique (casse de la liste) et
    dédoublonnés, côté `Indexer`.
- Le champ `gameMode` du document zcx (All/PvE/PvP) reste inchangé et distinct des tags.
- Rien à migrer : les tags hors liste n'existent pas encore en base.

## Contrat OpenAPI (`docs/openapi/teambuilds.yaml`)

- Nouvelle route `GET /api/v1/teambuilds/export` (schéma de réponse dédié : résumé
  enrichi de `document` et `status`).
- `PUT` : documentation du paramètre query `status`.
- Recherche : paramètre optionnel `status=`.
- Schéma `TeambuildSummary` : ajout de `status` (enum draft/published).
- Tags : enum documentée côté document zcx ingéré.
- Codes d'erreur : ajout de `forbidden_tag` et `too_many_characters` à l'enum.

## Tests (Minitest, patterns existants)

- `Teambuilds::Validator` : tag interdit, casse mixte acceptée, doublons, arbre > 512
  personnages → `too_many_characters`.
- `Teambuilds::Ingest` : `status` transmis, absent → conservé/`published` à la création ;
  changement de statut seul (document identique) → statut appliqué, `changed?` faux.
- `Teambuilds::Indexer` : variants indexés, positions séquentielles uniques,
  `player_count` racine uniquement.
- Requêtes API : export (auth requise, mélange public/mine/draft, documents intacts),
  `PUT` avec `status`, `GET` avec filtre `status=`, rejet 422 tag interdit.
- Modèle : scopes `draft`/`published`, `visible_to` inchangé par le statut.
- Vues : badge « Draft » affiché sur un build public en draft.

## Décisions et alternatives écartées

- **Export paginé ou NDJSON streamé** : écarté — complexité non justifiée à cette échelle ;
  l'utilisateur a explicitement demandé « tout en 1 fois ».
- **Draft = niveau de visibilité ou fusionné avec private/public** : écarté — choix
  utilisateur : statut orthogonal, purement informatif.
- **Tags libres / tag réservé** : écarté — choix utilisateur : liste fermée imposée,
  rejet explicite plutôt que filtrage silencieux.
- **Indexation racine seule** : écarté — choix utilisateur : tout indexer, avec garde-fou
  quantitatif pour éviter les arbres pathologiques.
