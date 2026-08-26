# Design — Tags administrables des teambuilds

Date : 2026-08-26
Statut : Approuvé (design validé en session)

## Contexte

Les teambuilds (`.zcx`) ingérés via l'API portent déjà une colonne `teambuilds.tags`
(`string[]` PostgreSQL, index GIN), alimentée depuis `document["tags"]` par
`Teambuilds::Indexer`. Aujourd'hui les tags sont libres : la constante
`Teambuilds::Validator::ALLOWED_TAGS` (9 valeurs canoniques) ne sert qu'à
normaliser la casse, sans jamais rejeter de valeur.

Objectifs de cette fonctionnalité :

1. Un endpoint API public qui expose la liste fermée des tags autorisés.
2. Cette liste devient le **seul** référentiel accepté lors des publications de
   builds via l'API (rejet 422 sinon).
3. La liste est **administrable en web** par les administrateurs GWRank.

Note historique : le retour client Z-Codex (`docs/gwrank_api_retours.md` §0.3)
demandait que les tags ne bloquent pas l'upload. Ce choix est volontairement
inversé ici (décision produit) — Z-Codex devra consommer `GET /api/v1/tags`.

Décisions prises en session :

- Tag non autorisé à l'ingestion → rejet du build (422).
- Endpoint tags public (sans Bearer token).
- Retrait d'un tag utilisé par des builds existants → désactivation douce ; les
  builds conservent leur tag historique, aucun nettoyage rétroactif.

## 1. Données et modèle

### Table `team_build_tags`

```ruby
create_table :team_build_tags do |t|
  t.string   :name,    null: false            # label affiché, ex. "GvG"
  t.string   :slug,    null: false            # normalisé minuscule, ex. "gvg"
  t.boolean  :active,  default: true, null: false
  t.integer  :position, default: 0, null: false
  t.timestamps
end
add_index :team_build_tags, :slug, unique: true
add_index :team_build_tags, [:active, :position]
```

Deux migrations :

1. Création de la table + index.
2. Seed idempotent (`find_or_create_by!` sur slug) des 9 tags canoniques actuels,
   positions séquentielles 1..9 :
   `GvG`, `HA`, `RA`, `TA`, `AB`, `FA`, `JQ`, `PvP`, `PvE`.

### Modèle `TeambuildTag`

- Validations : `name` présent ; `slug` présent, unique, format `/\A[a-z0-9]+\z/`.
- `before_validation :normalize_slug` (strip + downcase).
- Scopes : `ordered` → `order(:position, :name)` ; `active` → `where(active: true)`.
- Méthode de classe `.active_slugs` → `active.ordered.pluck(:slug)`.

Fixtures minitest mises à jour pour couvrir les cas actifs/désactivés.

## 2. Validation à l'ingestion (changement comportemental)

Fichiers impactés : `app/services/teambuilds/validator.rb`,
`app/services/teambuilds/ingest.rb`, `app/services/teambuilds/indexer.rb`.

- `Teambuilds::Validator` reçoit les slugs autorisés en paramètre, chargés par
  `Teambuilds::Ingest` via `TeambuildTag.active_slugs`. La constante
  `ALLOWED_TAGS` est supprimée : la migration de seed liste les 9 tags en dur,
  la table devient l'unique source de vérité.
- Chaque tag du document est comparé insensible à la casse aux slugs actifs :
  - correspondance → le nom officiel (`name`) remplace la valeur brute dans
    `teambuilds.tags` (normalisation conservée) ;
  - aucune correspondance → échec de validation.
- Échec → l'upsert `PUT /api/v1/teambuilds/:source_uuid` renvoie **422** avec :

```json
{
  "errors": [
    {
      "path": "tags",
      "code": "invalid_tag",
      "message": "Liste des tags autorisés disponible sur GET /api/v1/tags. Tags refusés : foo, bar"
    }
  ]
}
```

- La validation s'applique à toute ingestion (drafts inclus), pas seulement aux
  builds `published`.
- Aucun nettoyage des données existantes : les builds déjà stockés gardent leurs
  tags historiques même hors liste.

## 3. Endpoint API public

- Route : `GET /api/v1/tags` (`resources :tags, only: [:index]` dans le
  namespace `api/v1`), sans authentification.
- Contrôleur : `Api::V1::TagsController#index`
  (`skip_before_action :verify_authenticity_token`, pas de `verify_api_token`).
- Réponse (tags actifs uniquement, triés par `position` puis `name`) :

```json
{ "tags": ["GvG", "HA", "RA", "TA", "AB", "FA", "JQ", "PvP", "PvE"] }
```

- Header `Cache-Control: public, max-age=300` (liste peu volatile).

Impacts sur les endpoints existants :

- `GET /api/v1/teambuilds?tags=…` inchangé (filtre sur les tags stockés).
- `PUT /api/v1/teambuilds/:source_uuid` émet désormais le code d'erreur
  `invalid_tag` (déjà référencé dans `swagger_helper.rb`).

Documentation OpenAPI : nouvelle spec rswag `spec/requests/api/v1/tags_spec.rb`,
mise à jour de `spec/requests/api/v1/teambuilds_spec.rb` pour le 422,
régénération de `docs/openapi/teambuilds.yaml`.

## 4. Administration web

Namespace existant `administration` (gate `is_admin?` via
`Administration::ApplicationController#redirect_non_admins!`).

- Routes : `resources :team_build_tags` sous le namespace `administration`.
- Contrôleur : `Administration::TeamBuildTagsController <
  Administration::ApplicationController`.
  - `index` : tous les tags (actifs et désactivés), triés par `position`.
  - `create` : création inline depuis l'index ; slug auto-généré depuis le nom
    si absent.
  - `update` : édition `name`, `position`, toggle `active`.
  - **Pas de `destroy` physique** : la suppression est la désactivation
    (`active: false`), réversible et sans perte d'historique.
- Vues : page unique `index` avec formulaire d'ajout en tête, édition par ligne,
  bouton Activer/Désactiver ; lien « Tags » dans la nav de
  `layouts/administration.html.erb`.
- Strong parameters : `name`, `position`, `active` (+ `slug` généré serveur).

## 5. Tests

Double stack existante (minitest principal + rspec/rswag pour l'API) :

- Minitest :
  - `test/models/team_build_tag_test.rb` : validations, normalisation du slug,
    scopes, `.active_slugs`.
  - `test/controllers/api/v1/tags_controller_test.rb` : 200 sans auth, tri par
    position, exclusion des désactivés.
  - Extension `test/controllers/api/v1/teambuilds_controller_test.rb` : 422
    `invalid_tag` quand tag hors liste ; tag avec casse différente normalisé et
    accepté ; draft concerné comme published.
  - Tests contrôleur admin : accès refusé pour non-admin, create/update/toggle
    fonctionnels.
- RSpec/rswag : `spec/requests/api/v1/tags_spec.rb` + mise à jour
  `teambuilds_spec.rb` (422).

## Hors périmètre

- CRUD web des builds / tags côté UI publique (aucune édition web des builds
  n'existe).
- Migration ou nettoyage des tags historiques hors liste.
- Internationalisation de l'admin (français, comme le reste de l'app).
