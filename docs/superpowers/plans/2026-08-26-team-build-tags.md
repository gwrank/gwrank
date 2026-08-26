# Team Build Tags administrables — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Liste fermée de tags teambuilds, exposée par `GET /api/v1/tags`, seule acceptée à la publication via l'API, administrable en web par les admins GWRank.

**Architecture:** Nouvelle table `team_build_tags` (source de vérité : `name` affiché + `slug` normalisé + `active` + `position`). `Teambuilds::Validator` valide contre les slugs actifs passés par `Teambuilds::Ingest` ; l'`Indexer` normalise la casse vers le nom officiel. Endpoint public JSON dans `Api::V1`, CRUD minimal dans le namespace `administration`.

**Tech Stack:** Rails 8.1 / Ruby 3.4 / PostgreSQL / Minitest (+ RSpec rswag pour la doc OpenAPI) / Turbo.

**Spec:** `docs/superpowers/specs/2026-08-26-team-build-tags-design.md`

**Conventions projet à respecter:**
- Minitest = stack principale (`test/`), RSpec/rswag uniquement pour documenter l'API (`spec/requests/api/v1/`)
- Erreurs API : `{ "errors": [{ "path", "code", "message" }] }`, messages en français
- Admin : contrôleurs `Administration::*Controller < Administration::ApplicationController` (gate `is_admin?`), layout avec classes `gw-window`, `gw-table`, `gw-input`, `gw-btn`
- `docs/` est gitignoré : `git add -f` pour tout NOUVEAU fichier sous `docs/` (les fichiers déjà trackés comme `docs/openapi/teambuilds.yaml` se committent normalement)

---

### Task 1: Table `team_build_tags`, modèle et fixtures minitest

**Files:**
- Create: `db/migrate/20260826090000_create_team_build_tags.rb`
- Create: `app/models/teambuild_tag.rb`
- Create: `test/fixtures/team_build_tags.yml`
- Test: `test/models/team_build_tag_test.rb`

- [ ] **Step 1: Écrire les tests du modèle (échouent : table/classe inexistantes)**

```ruby
# test/models/team_build_tag_test.rb
require "test_helper"

class TeambuildTagTest < ActiveSupport::TestCase
  test "generates slug from name when absent" do
    tag = TeambuildTag.new(name: "GvG")
    assert tag.save
    assert_equal "gvg", tag.slug
  end

  test "strips and downcases a provided slug" do
    tag = TeambuildTag.new(name: "Heroes Ascent", slug: "  HA ")
    assert tag.save
    assert_equal "ha", tag.slug
  end

  test "rejects duplicate slug regardless of case" do
    team_build_tags(:gvg)
    dup = TeambuildTag.new(name: "GVG", slug: "GVG")
    refute dup.valid?
    assert dup.errors[:slug].any?
  end

  test "rejects slug with characters outside [a-z0-9]" do
    refute TeambuildTag.new(name: "Bad Tag", slug: "bad tag!").valid?
  end

  test "requires a name" do
    refute TeambuildTag.new(slug: "x").valid?
  end

  test "active_slugs returns active slugs ordered by position" do
    assert_equal %w[gvg ha ra ta ab fa jq pvp pve], TeambuildTag.active_slugs
  end

  test "ordered includes deactivated tags last for admin listing" do
    assert_includes TeambuildTag.ordered.map(&:slug), "legacy"
  end
end
```

- [ ] **Step 2: Vérifier que les tests échouent**

Run: `bin/rails test test/models/team_build_tag_test.rb -v`
Expected: FAIL (`uninitialized constant TeambuildTag` ou table absente)

- [ ] **Step 3: Créer la migration de création**

```bash
bin/rails generate migration CreateTeamBuildTags
```

Puis éditer `db/migrate/20260826090000_create_team_build_tags.rb` :

```ruby
class CreateTeamBuildTags < ActiveRecord::Migration[8.1]
  def change
    create_table :team_build_tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :team_build_tags, :slug, unique: true
    add_index :team_build_tags, [:active, :position]
  end
end
```

(Supprimer le fichier de migration vide généré si le timestamp diffère ; garder un seul fichier.)

- [ ] **Step 4: Créer le modèle**

```ruby
# app/models/teambuild_tag.rb
class TeambuildTag < ApplicationRecord
  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9]+\z/ }

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }

  def self.active_slugs
    active.ordered.pluck(:slug)
  end

  private

  def normalize_slug
    self.slug = slug.presence&.strip&.downcase || name.to_s.strip.parameterize(separator: "")
  end
end
```

- [ ] **Step 5: Créer les fixtures**

```yaml
# test/fixtures/team_build_tags.yml
gvg: { name: "GvG", slug: "gvg", position: 1, active: true }
ha: { name: "HA", slug: "ha", position: 2, active: true }
ra: { name: "RA", slug: "ra", position: 3, active: true }
ta: { name: "TA", slug: "ta", position: 4, active: true }
ab: { name: "AB", slug: "ab", position: 5, active: true }
fa: { name: "FA", slug: "fa", position: 6, active: true }
jq: { name: "JQ", slug: "jq", position: 7, active: true }
pvp: { name: "PvP", slug: "pvp", position: 8, active: true }
pve: { name: "PvE", slug: "pve", position: 9, active: true }
legacy: { name: "Legacy", slug: "legacy", position: 10, active: false }
```

- [ ] **Step 6: Migrer puis vérifier les tests**

Run: `bin/rails db:migrate && bin/rails test test/models/team_build_tag_test.rb -v`
Expected: 7 runs, 0 failures

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260826090000_create_team_build_tags.rb app/models/teambuild_tag.rb test/fixtures/team_build_tags.yml test/models/team_build_tag_test.rb db/schema.rb
git commit -m "feat(tags): team_build_tags table and model"
```

---

### Task 2: Migration de seed des 9 tags canoniques

**Files:**
- Create: `db/migrate/20260826100000_seed_team_build_tags.rb`
- Modify: `db/seeds.rb` (append)

- [ ] **Step 1: Créer la migration de seed**

```ruby
class SeedTeamBuildTags < ActiveRecord::Migration[8.1]
  TAGS = [%w[GvG gvg], %w[HA ha], %w[RA ra], %w[TA ta], %w[AB ab],
          %w[FA fa], %w[JQ jq], %w[PvP pvp], %w[PvE pve]].freeze

  def up
    TAGS.each_with_index do |(name, slug), index|
      TeambuildTag.find_or_create_by!(slug: slug) do |tag|
        tag.name = name
        tag.position = index + 1
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

- [ ] **Step 2: Ajouter le même seed idempotent dans `db/seeds.rb` (append)**

```ruby
# Closed list of teambuild tags (mirrors the data migration; keeps fresh envs bootstrapped)
[%w[GvG gvg], %w[HA ha], %w[RA ra], %w[TA ta], %w[AB ab],
 %w[FA fa], %w[JQ jq], %w[PvP pvp], %w[PvE pve]].each_with_index do |(name, slug), index|
  TeambuildTag.find_or_create_by!(slug: slug) do |tag|
    tag.name = name
    tag.position = index + 1
  end
end
```

- [ ] **Step 3: Appliquer aux bases dev et test**

Run: `bin/rails db:migrate && RAILS_ENV=test bin/rails db:migrate`
Expected: migrations appliquées sans erreur sur les deux environnements.
(Raison : les specs rswag ne chargent pas les fixtures minitest ; elles s'appuient sur les données persistées de la base de test, comme pour professions/skills.)

- [ ] **Step 4: Commit**

```bash
git add db/migrate/20260826100000_seed_team_build_tags.rb db/seeds.rb db/schema.rb
git commit -m "feat(tags): seed canonical closed tag list"
```

---

### Task 3: `Teambuilds::Validator` accepte une whitelist optionnelle

**Files:**
- Modify: `app/services/teambuilds/validator.rb:30` (suppression constante) et `validate_tags` (~ligne 97)
- Test: `test/services/teambuilds/validator_test.rb` (append)

- [ ] **Step 1: Écrire les tests qui échouent (append au fichier existant)**

```ruby
  test "skips the whitelist when none is provided" do
    @doc["tags"] = ["Whatever"]
    assert_empty errors_for_whitelisted(@doc, nil)
  end

  test "accepts whitelisted tags case-insensitively" do
    @doc["tags"] = ["gvg"]
    assert_empty errors_for_whitelisted(@doc, %w[gvg])
  end

  test "rejects unknown tags when a whitelist is provided" do
    @doc["tags"] = ["Foo", "GvG"]
    errors = errors_for_whitelisted(@doc, %w[gvg])
    assert_equal ["invalid_tag"], errors.map { |e| e["code"] }.uniq
    assert_equal "$.tags", errors.first["path"]
    assert_includes errors.first["message"], "Foo"
    assert_not_includes errors.first["message"], "GvG"
  end

  private

  def errors_for_whitelisted(document, allowed)
    Validator.validate(document, allowed_tags: allowed)
  end
```

Attention : le fichier existant définit déjà un `private` suivi de `errors_for`. Placer ces tests AVANT ce bloc `private` existant et n'ajouter qu'une méthode privée `errors_for_whitelisted` à côté de `errors_for` (ne pas dupliquer le mot-clé `private`). Le helper existant :

```ruby
  def errors_for(mutated)
    Validator.validate(mutated)
  end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/services/teambuilds/validator_test.rb -v`
Expected: FAIL (`unknown keyword :allowed_tags`)

- [ ] **Step 3: Implémenter dans `validator.rb`**

Supprimer la ligne 30 :
```ruby
    ALLOWED_TAGS = %w[GvG HA RA TA AB FA JQ PvP PvE].freeze
```

Modifier les méthodes de classe et d'instance :

```ruby
    def self.validate(document, allowed_tags: nil)
      unless document.is_a?(Hash)
        return [{ "path" => "$", "code" => "not_an_object", "message" => "Le document racine doit être un objet JSON" }]
      end
      new(document, allowed_tags: allowed_tags).call
    end
```

```ruby
    def initialize(document, allowed_tags: nil)
      @document = document
      @allowed_tags = allowed_tags
      @errors = []
      @character_count = 0
    end
```

Remplacer `validate_tags` et ajouter `reject_unknown_tags` :

```ruby
    def validate_tags(tags)
      return unless tags.is_a?(Array)
      if tags.size > MAX_TAGS
        return add_error("$.tags", "invalid_tag", "Au maximum #{MAX_TAGS} tags sont admis")
      end
      tags.each_with_index do |tag, i|
        next if valid_tag?(tag)
        add_error("$.tags[#{i}]", "invalid_tag",
                  %(Tag invalide : chaîne non vide de #{TAG_MAX_LENGTH} caractères maximum))
      end
      reject_unknown_tags(tags)
    end

    def reject_unknown_tags(tags)
      return unless @allowed_tags
      unknown = tags.select { |tag| valid_tag?(tag) && !@allowed_tags.include?(tag.to_s.downcase) }
      return if unknown.empty?
      add_error("$.tags", "invalid_tag",
                "Liste des tags autorisés disponible sur GET /api/v1/tags. Tags refusés : #{unknown.join(', ')}")
    end
```

- [ ] **Step 4: Vérifier que toute la suite validator passe**

Run: `bin/rails test test/services/teambuilds/validator_test.rb -v`
Expected: tous PASS (les tests existants appellent `validate(doc)` sans kwarg → comportement inchangé)

- [ ] **Step 5: Commit**

```bash
git add app/services/teambuilds/validator.rb test/services/teambuilds/validator_test.rb
git commit -m "feat(tags): validator accepts an optional allowed-tags whitelist"
```

---

### Task 4: Branchement Ingest + Indexer (liste fermée appliquée)

**Files:**
- Modify: `app/services/teambuilds/ingest.rb:20`
- Modify: `app/services/teambuilds/indexer.rb:28-33`
- Test: `test/services/teambuilds/ingest_test.rb` (append), `test/services/teambuilds/indexer_test.rb` (append)

- [ ] **Step 1: Écrire les tests qui échouent (append aux fichiers existants)**

Dans `test/services/teambuilds/ingest_test.rb` (adapter au style existant du fichier — il utilise `create_player` et `load_zcx`) :

```ruby
  test "rejects ingestion of a build tagged outside the closed list" do
    doc = load_zcx
    doc["id"] = "ccccccc1-0000-0000-0000-000000000001"
    doc["tags"] = ["GvG", "CustomTag"]
    result = Ingest.call(player: create_player, source_uuid: doc["id"], document: doc)
    refute result.ok?
    error = result.errors.find { |e| e["code"] == "invalid_tag" }
    assert_includes error["message"], "CustomTag"
  end
```

Dans `test/services/teambuilds/indexer_test.rb` :

```ruby
  test "maps lowercase tags to the official active tag name" do
    player = create_player
    doc = load_zcx
    doc["tags"] = ["gvg"]
    teambuild = player.teambuilds.new(source_uuid: doc["id"])
    Teambuilds::Indexer.call(teambuild)
    assert_equal ["GvG"], teambuild.tags
  end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/services/teambuilds/ingest_test.rb test/services/teambuilds/indexer_test.rb -v`
Expected: FAIL — l'ingestion accepte `CustomTag` (aucune whitelist passée)

- [ ] **Step 3: Modifier `ingest.rb` ligne 20**

```ruby
      errors = Validator.validate(@document, allowed_tags: TeambuildTag.active_slugs)
```

- [ ] **Step 4: Modifier `indexer.rb` — remplacer `canonical_tags`**

```ruby
    def canonical_tags
      names = TeambuildTag.active.index_by(&:slug)
      Array(@document["tags"]).filter_map do |tag|
        next unless tag.is_a?(String)
        names[tag.to_s.downcase]&.name || tag
      end.uniq
    end
```

- [ ] **Step 5: Vérifier les suites services + contrôleur API complètes**

Run: `bin/rails test test/services/teambuilds/ test/controllers/api/v1/ -v`
Expected: tous PASS — y compris les tests existants (le fixture fournit `gvg` actif).

- [ ] **Step 6: Commit**

```bash
git add app/services/teambuilds/ingest.rb app/services/teambuilds/indexer.rb test/services/teambuilds/
git commit -m "feat(tags): enforce closed tag list on API ingestion"
```

---

### Task 5: Endpoint public `GET /api/v1/tags`

**Files:**
- Modify: `config/routes.rb:6-12`
- Create: `app/controllers/api/v1/tags_controller.rb`
- Test: `test/controllers/api/v1/tags_controller_test.rb`

- [ ] **Step 1: Écrire les tests qui échouent**

```ruby
# test/controllers/api/v1/tags_controller_test.rb
require "test_helper"

module Api::V1
  class TagsControllerTest < ActionDispatch::IntegrationTest
    test "is public (no bearer token)" do
      get api_v1_tags_path
      assert_response :success
    end

    test "lists active tags ordered by position" do
      get api_v1_tags_path
      assert_equal %w[GvG HA RA TA AB FA JQ PvP PvE], response.parsed_body["tags"]
    end

    test "excludes deactivated tags" do
      team_build_tags(:gvg).update!(active: false)
      get api_v1_tags_path
      assert_not_includes response.parsed_body["tags"], "GvG"
    end

    test "sets a short shared cache header" do
      get api_v1_tags_path
      assert_match "max-age=300", response.headers["Cache-Control"]
    end
  end
end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/controllers/api/v1/tags_controller_test.rb -v`
Expected: FAIL (route inconnue)

- [ ] **Step 3: Route + contrôleur**

Dans `config/routes.rb`, ajouter dans `namespace :api` / `namespace :v1` :

```ruby
      resources :tags, only: [:index]
```

```ruby
# app/controllers/api/v1/tags_controller.rb
class Api::V1::TagsController < ApplicationController
  def index
    response.set_header("Cache-Control", "public, max-age=300")
    render json: { tags: TeambuildTag.active.ordered.pluck(:name) }
  end
end
```

(Pas de `skip_before_action` ni de token : GET public, même pattern que `Api::V1::ItemsController`.)

- [ ] **Step 4: Vérifier le passage**

Run: `bin/rails test test/controllers/api/v1/tags_controller_test.rb -v`
Expected: 4 runs, 0 failures

- [ ] **Step 5: Smoke manuel dev (optionnel mais rapide)**

Run: `bin/rails runner 'puts { tags: TeambuildTag.active.ordered.pluck(:name) }.to_json'`
Expected: `{"tags":["GvG","HA","RA","TA","AB","FA","JQ","PvP","PvE"]}`

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/tags_controller.rb test/controllers/api/v1/tags_controller_test.rb
git commit -m "feat(api): public endpoint listing allowed teambuild tags"
```

---

### Task 6: Tests de comportement upsert côté contrôleur + doc OpenAPI rswag

**Files:**
- Test: `test/controllers/api/v1/teambuilds_controller_test.rb` (append)
- Create: `spec/requests/api/v1/tags_spec.rb`
- Modify: `spec/requests/api/v1/teambuilds_spec.rb` (exemple 422 invalid_tag)
- Modify: `spec/swagger_helper.rb` (schéma TagsResponse)
- Regenerate: `docs/openapi/teambuilds.yaml`

- [ ] **Step 1: Ajouter les tests minitest upsert (append au fichier existant)**

```ruby
    test "upsert rejects tags outside the closed list" do
      doc = JSON.parse(@document.to_json)
      doc["id"] = "ccccccc1-0000-0000-0000-000000000001"
      doc["tags"] << "CustomTag"
      put_doc(@owner, doc)
      assert_response :unprocessable_entity
      error = response.parsed_body["errors"].find { |e| e["code"] == "invalid_tag" }
      assert_includes error["message"], "CustomTag"
      assert_not Teambuild.exists?(source_uuid: doc["id"])
    end

    test "upsert normalizes tag case against active slugs" do
      doc = JSON.parse(@document.to_json)
      doc["id"] = "ccccccc1-0000-0000-0000-000000000002"
      doc["tags"] = ["gvg"]
      put_doc(@owner, doc)
      assert_response :created
      assert_equal ["GvG"], Teambuild.find_by(source_uuid: doc["id"]).tags
    end

    test "closed list applies to drafts too" do
      doc = JSON.parse(@document.to_json)
      doc["id"] = "ccccccc1-0000-0000-0000-000000000003"
      doc["tags"] = ["Nope"]
      put_doc(@owner, doc, status: "draft")
      assert_response :unprocessable_entity
    end
```

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb -v`
Expected: tous PASS (le comportement est déjà branché par la Task 4)

Commit intermédiaire :
```bash
git add test/controllers/api/v1/teambuilds_controller_test.rb
git commit -m "test(api): cover closed tag list rejection on upsert"
```

- [ ] **Step 2: Ajouter le schéma de réponse dans `spec/swagger_helper.rb`**

Dans `components/schemas` (à côté de `Pagination`) :

```ruby
          TagsResponse: {
            type: :object,
            required: ['tags'],
            properties: {
              tags: {
                type: :array,
                items: { type: :string },
                description: 'Closed list of tags accepted when publishing teambuilds, ordered by position'
              }
            }
          },
```

- [ ] **Step 3: Créer `spec/requests/api/v1/tags_spec.rb`**

```ruby
# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Tags API', swagger_doc: 'teambuilds.yaml', type: :request do
  path '/api/v1/tags' do
    get 'List allowed teambuild tags' do
      produces 'application/json'
      security []
      description <<~DESC.squish
        Closed list of tags accepted when publishing teambuilds. Public endpoint (no bearer token).
        Maintained by GWRank administrators; clients should refresh periodically (Cache-Control max-age=300).
      DESC

      response(200, 'returns active tags ordered by position') do
        before do
          TeambuildTag.delete_all
          %w[GvG HA RA TA AB FA JQ PvP PvE].each_with_index do |name, index|
            TeambuildTag.create!(name: name, slug: name.downcase, position: index + 1)
          end
          TeambuildTag.create!(name: 'Legacy', slug: 'legacy', position: 10, active: false)
        end

        schema '$ref' => '#/components/schemas/TagsResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tags']).to eq(%w[GvG HA RA TA AB FA JQ PvP PvE])
        end
      end
    end
  end
end
```

- [ ] **Step 4: Documenter le 422 invalid_tag dans `spec/requests/api/v1/teambuilds_spec.rb`**

Repérer le bloc `path '/api/v1/teambuilds/{source_uuid}'` avec le `put` (upsert). À la suite des réponses 200/201/412 existantes, ajouter :

```ruby
      response(422, 'rejects tags outside the closed list') do
        before do
          @owner = create_api_player
        end
        let(:source_uuid) { 'bbbbbbb1-0000-0000-0000-000000000009' }
        let(:body) { zcx_variant(source_uuid, tags: ['NotARealTag']) }

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |e| e['code'] }
          expect(codes).to include('invalid_tag')
        end
      end
```

Adapter `let(:body)` au nom exact utilisé par les exemples PUT voisins du fichier (lire les déclarations `let` du bloc put avant d'écrire ; conserver leurs conventions, ex. `let(:payload)` ou paramètre raw body). L'important : un POST/PUT dont le document porte `tags: ['NotARealTag']` renvoie 422 avec `invalid_tag`.

- [ ] **Step 5: Exécuter rspec et régénérer le YAML OpenAPI**

Run: `bundle exec rake rswag:specs:swaggerize PATTERN="spec/requests/api/v1/{tags_spec.rb,teambuilds_spec.rb}" 2>&1 || bundle exec rake rswag:specs:swaggerize`
Expected: exemples verts ; `docs/openapi/teambuilds.yaml` régénéré avec `/api/v1/tags`.

Si la génération échoue sur `security []` (DSL rswag), retirer la ligne `security []` et mentionner « Public endpoint » uniquement dans la description, puis relancer.

- [ ] **Step 6: Commit**

```bash
git add spec/swagger_helper.rb spec/requests/api/v1/tags_spec.rb spec/requests/api/v1/teambuilds_spec.rb docs/openapi/teambuilds.yaml
git commit -m "docs(api): document GET /tags and invalid_tag rejection in OpenAPI"
```

---

### Task 7: Back-office admin des tags

**Files:**
- Modify: `config/routes.rb:34-47`
- Create: `app/controllers/administration/team_build_tags_controller.rb`
- Create: `app/views/administration/team_build_tags/index.html.erb`
- Modify: `app/views/layouts/administration.html.erb:16-22` (nav)
- Test: `test/controllers/administration/team_build_tags_controller_test.rb`

- [ ] **Step 1: Écrire les tests contrôleur qui échouent**

```ruby
# test/controllers/administration/team_build_tags_controller_test.rb
require "test_helper"

module Administration
  class TeamBuildTagsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    setup do
      @admin = create_player(is_admin: true)
      @player = create_player
    end

    test "redirects non-admin players" do
      sign_in @player
      get administration_team_build_tags_path
      assert_redirected_to root_path
    end

    test "admin lists tags" do
      sign_in @admin
      get administration_team_build_tags_path
      assert_response :success
      assert_select "body", text: /GvG/
    end

    test "admin creates a tag from its name" do
      sign_in @admin
      assert_difference "TeambuildTag.count", 1 do
        post administration_team_build_tags_path, params: { team_build_tag: { name: "Tombs" } }
      end
      assert_redirected_to administration_team_build_tags_path
      assert_equal "tombs", TeambuildTag.find_by(name: "Tombs").slug
    end

    test "admin updates name, position and toggles active" do
      sign_in @admin
      tag = team_build_tags(:gvg)
      patch administration_team_build_tag_path(tag),
            params: { team_build_tag: { name: "GvG", position: 42, active: false } }
      assert_redirected_to administration_team_build_tags_path
      assert_equal false, tag.reload.active
      assert_equal 42, tag.position
    end

    test "slug is immutable on update" do
      sign_in @admin
      tag = team_build_tags(:gvg)
      patch administration_team_build_tag_path(tag),
            params: { team_build_tag: { name: "Renamed", position: 42, active: true } }
      assert_equal "gvg", tag.reload.slug
    end
  end
end
```

Run: `bin/rails test test/controllers/administration/team_build_tags_controller_test.rb -v`
Expected: FAIL (routes inexistantes)

- [ ] **Step 2: Route**

Dans `namespace :administration` de `config/routes.rb` :

```ruby
    resources :team_build_tags, only: [:index, :create, :update]
```

- [ ] **Step 3: Contrôleur**

```ruby
# app/controllers/administration/team_build_tags_controller.rb
module Administration
  class TeamBuildTagsController < ApplicationController
    def index
      @team_build_tags = TeambuildTag.ordered
      @team_build_tag = TeambuildTag.new
    end

    def create
      @team_build_tag = TeambuildTag.new(team_build_tag_params)
      if @team_build_tag.save
        redirect_to administration_team_build_tags_path, notice: "Tag ajouté."
      else
        @team_build_tags = TeambuildTag.ordered
        flash.now[:alert] = @team_build_tag.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def update
      @team_build_tag = TeambuildTag.find(params[:id])
      if @team_build_tag.update(team_build_tag_params)
        redirect_to administration_team_build_tags_path, notice: "Tag mis à jour."
      else
        redirect_to administration_team_build_tags_path,
                    alert: @team_build_tag.errors.full_messages.to_sentence
      end
    end

    private

    def team_build_tag_params
      params.require(:team_build_tag).permit(:name, :position, :active)
    end
  end
end
```

Note : `:slug` volontairement absent des strong parameters — généré à la création depuis `name`, jamais modifiable après.

- [ ] **Step 4: Vue index**

```erb
<%# app/views/administration/team_build_tags/index.html.erb %>
<div class="space-y-4">
  <div class="gw-window gw-frame">
    <div class="gw-window-header">
      <h1 class="gw-title text-base m-0">Teambuild tags</h1>
      <span class="gw-count text-sm"><%= pluralize @team_build_tags.count, 'tag' %></span>
    </div>

    <%= form_with model: @team_build_tag, url: administration_team_build_tags_path, class: "flex flex-wrap gap-2 items-end py-3 border-b border-gold-600" do |form| %>
      <div>
        <%= form.label :name, 'New tag name', class: 'block text-sm text-parchment' %>
        <%= form.text_field :name, class: 'gw-input' %>
      </div>
      <%= form.submit 'Add tag', class: 'gw-btn mt-1' %>
    <% end %>

    <div class="divide-y">
      <% @team_build_tags.each do |tag| %>
        <%= form_with model: tag, url: administration_team_build_tag_path(tag), class: "flex flex-wrap gap-3 items-center py-2" do |form| %>
          <%= form.text_field :name, class: 'gw-input w-40' %>
          <code class="text-muted"><%= tag.slug %></code>
          <%= form.number_field :position, min: 0, class: 'gw-input w-20' %>
          <label class="flex items-center gap-1 text-sm text-parchment">
            <%= form.check_box :active %> Active
          </label>
          <%= form.submit 'Save', class: 'gw-btn gw-btn--ghost' %>
        <% end %>
      <% end %>
    </div>

    <p class="text-sm text-muted pt-2">
      Deactivating a tag hides it from <code>GET /api/v1/tags</code> and blocks it on new publications;
      existing builds keep their historical tags.
    </p>
  </div>
</div>
```

- [ ] **Step 5: Lien dans la nav admin (`layouts/administration.html.erb`)**

Après le lien Claims :

```erb
        <% tags_active = gw_nav_active?(administration_team_build_tags_path) %>
        <%= link_to "Tags", administration_team_build_tags_path, class: "gw-tab #{'gw-tab--active' if tags_active}", aria: { current: ("page" if tags_active) } %>
```

- [ ] **Step 6: Vérifier les tests**

Run: `bin/rails test test/controllers/administration/ -v`
Expected: 5 runs, 0 failures

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/administration/team_build_tags_controller.rb app/views/administration/team_build_tags/index.html.erb app/views/layouts/administration.html.erb test/controllers/administration/team_build_tags_controller_test.rb
git commit -m "feat(admin): web management of teambuild tags"
```

---

### Task 8: Vérification globale

- [ ] **Step 1: Suite minitest complète**

Run: `bin/rails test`
Expected: 0 failures, 0 errors

- [ ] **Step 2: Suite rspec complète**

Run: `bundle exec rspec`
Expected: 0 failures

- [ ] **Step 3: Scan sécurité rapide (nouveau code admin/API)**

Run: `bundle exec brakeman --quiet 2>/dev/null || bin/brakeman --quiet || echo "brakeman indisponible"`
Expected: aucune vulnérabilité nouvelle liée aux changements.

- [ ] **Step 4: Vérification manuelle bout-en-bout en dev (serveur lancé)**

```bash
curl -s http://localhost:3000/api/v1/tags
```
Expected: `{"tags":["GvG","HA","RA","TA","AB","FA","JQ","PvP","PvE"]}`

En admin (`/administration/team_build_tags`) : désactiver `HA` → re-vérifier curl sans `HA` ; publier via API un build avec `"tags": ["HA"]` → 422 `invalid_tag` ; réactiver.

- [ ] **Step 5: Commit final éventuel (schema.rb, corrections)**

```bash
git status
git add -A ':!tasks'
git commit -m "chore(tags): final adjustments after full verification"
```
(ne rien committer si `git status` est propre)

---

## Self-review (effectuée lors de la rédaction)

1. **Couverture spec** : table+modèle+seed (Tasks 1-2) · validation/rejet 422 drafts inclus (Tasks 3-4, 6) · endpoint public trié + cache (Task 5, 6) · admin CRUD sans destroy + nav (Task 7) · double stack tests + OpenAPI (Tasks 5-7) · données historiques intactes (aucune migration de nettoyage — conformes).
2. **Placeholders** : aucun TBD/TODO ; chaque étape contient son code exact.
3. **Cohérence types** : `TeambuildTag.active_slugs` (Task 1) consommé tel quel en Task 4 ; `allowed_tags:` kwarg identique entre Tasks 3 et 4 ; routes/noms (`administration_team_build_tags_path`) cohérents entre tests, contrôleur et vues.
