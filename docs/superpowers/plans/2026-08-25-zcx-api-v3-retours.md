# Retours Z-Codex v3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Livrer les 5 retours Z-Codex v3 : verrou optimiste If-Match/412, tags libres, `updated_since`, `documentHash`/ETag, et doc `/api-docs` corrigée + entièrement en anglais.

**Architecture:** Aucune migration. Le verrou réutilise le `document_hash` SHA-256 existant (déjà connu de Z-Codex). Les tags passent d'une liste fermée à une validation structurelle bornée, les 9 valeurs canoniques restant seules indexées pour les filtres. La doc est régénérée depuis la source rswag (`spec/swagger_helper.rb` + `spec/requests/api/v1/teambuilds_spec.rb`).

**Tech Stack:** Rails 8.1, Minitest (contrôleurs/services), RSpec+rswag (doc testée), PostgreSQL.

**Spec:** `docs/superpowers/specs/2026-08-25-zcx-api-v3-retours-design.md`

**Note langue :** seule la *documentation* passe en anglais. Les messages d'erreur runtime (payloads `errors[].message`) restent en français, cohérents avec l'existant (`malformed_json`, etc.) — hors périmètre validé.

**Note git :** `docs/` est partiellement gitigné ; `git add -f docs/openapi/teambuilds.yaml docs/superpowers/plans/...` si besoin (convention du repo : le YAML et les plans sont trackés).

---

### Task 1: Tags libres bornés (`invalid_tag` remplace `forbidden_tag`)

**Files:**
- Modify: `test/services/teambuilds/validator_test.rb:97-112`
- Modify: `app/services/teambuilds/validator.rb:30,95-106`
- Modify: `app/services/teambuilds/indexer.rb:28-32`
- Test: `test/controllers/api/v1/teambuilds_controller_test.rb`
- Test: `test/services/teambuilds/indexer_test.rb`

- [ ] **Step 1: Réécrire les tests validator tags (TDD rouge)**

Dans `test/services/teambuilds/validator_test.rb`, remplacer les trois tests `rejects tags outside the closed list`, `accepts allowed tags case-insensitively` et `rejects non-string tags` (lignes 97-112) par :

```ruby
    test "accepts free-form tags" do
      @doc["tags"] = ["GvG", "meta", "à tester", "Ramstram"]
      assert_empty errors_for(@doc)
    end

    test "accepts canonical tags case-insensitively" do
      @doc["tags"] = ["gvg", "PvE"]
      assert_empty errors_for(@doc)
    end

    test "rejects non-string tags" do
      @doc["tags"] = ["GvG", 42]
      assert_includes errors_for(@doc).map { |e| e["code"] }, "invalid_tag"
    end

    test "rejects empty or whitespace-only tags" do
      @doc["tags"] = [""]
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
      @doc["tags"] = ["   "]
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
    end

    test "rejects tags over 64 characters" do
      @doc["tags"] = ["x" * 65]
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
      @doc["tags"] = ["x" * 64]
      assert_empty errors_for(@doc)
    end

    test "rejects more than 24 tags" do
      @doc["tags"] = Array.new(25) { |i| "tag#{i}" }
      assert_equal ["invalid_tag"], errors_for(@doc).map { |e| e["code"] }
      @doc["tags"] = Array.new(24) { |i| "tag#{i}" }
      assert_empty errors_for(@doc)
    end
```

- [ ] **Step 2: Vérifier le rouge**

Run: `bin/rails test test/services/teambuilds/validator_test.rb -n "/tags|free-form|canonical/i"`
Expected: FAIL — les tests attendent l'acceptation des tags libres mais `forbidden_tag` est encore émis.

- [ ] **Step 3: Implémenter la validation structurelle dans `validator.rb`**

Ligne 30, conserver `ALLOWED_TAGS` (elle devient la liste canonique, utilisée par l'indexer) et ajouter juste après :

```ruby
    ALLOWED_TAGS = %w[GvG HA RA TA AB FA JQ PvP PvE].freeze
    MAX_TAGS = 24
    TAG_MAX_LENGTH = 64
```

Remplacer `validate_tags` et supprimer `allowed_tag?` (lignes 95-106) :

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
    end

    def valid_tag?(tag)
      tag.is_a?(String) && tag.length <= TAG_MAX_LENGTH && !tag.strip.empty?
    end
```

Puis modifier `canonical_tags` dans `app/services/teambuilds/indexer.rb` (lignes 28-32) :

```ruby
    def canonical_tags
      Array(@document["tags"]).filter_map do |tag|
        next unless tag.is_a?(String)
        Teambuilds::Validator::ALLOWED_TAGS.find { |allowed| allowed.casecmp(tag).zero? } || tag
      end.uniq
    end
```

- [ ] **Step 4: Vérifier le vert**

Run: `bin/rails test test/services/teambuilds/validator_test.rb test/services/teambuilds/indexer_test.rb test/models/teambuild_test.rb`
Expected: PASS

- [ ] **Step 5: Test contrôleur bout-en-bout**

Ajouter dans `test/controllers/api/v1/teambuilds_controller_test.rb` après le test `upsert accepts a status param and summaries expose it` :

```ruby
    test "upsert accepts free-form tags, keeps them in export, filters stay canonical" do
      doc = JSON.parse(@document.to_json)
      doc["id"] = "eeeeeee2-0000-0000-0000-000000000001"
      doc["tags"] = ["meta", "gvg", "guild name"]
      put_doc(@owner, doc)
      assert_response :created

      get api_v1_teambuilds_path(tags: "GvG"), headers: auth_headers(@owner)
      names = response.parsed_body["teambuilds"].map { |t| t["name"] }
      assert_includes names, "GvG Split"
      assert_not_includes names, "Free Tagged"

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      mine = response.parsed_body["teambuilds"].find { |entry| entry["sourceId"] == doc["id"] }
      assert_equal ["meta", "GvG", "guild name"], mine["tags"]
    end
```

Note : le nom stocké reste `"GvG Split"` (le doc inséré garde `name`) — l'assertion `assert_not_includes names, "Free Tagged"` vérifie qu'aucun build fantôme n'apparaît ; ajuster si un nom distinct est préféré en renommant `doc["name"] = "Free Tagged"` avant le put et en inversant includes/not_includes sur ce nom.

Version recommandée (sans ambiguïté) :

```ruby
    test "upsert accepts free-form tags, keeps them in export, filters stay canonical" do
      doc = JSON.parse(@document.to_json)
      doc["id"] = "eeeeeee2-0000-0000-0000-000000000001"
      doc["name"] = "Free Tagged"
      doc["tags"] = ["meta", "gvg", "guild name"]
      put_doc(@owner, doc)
      assert_response :created

      get api_v1_teambuilds_path(tags: "GvG"), headers: auth_headers(@owner)
      names = response.parsed_body["teambuilds"].map { |t| t["name"] }
      assert_not_includes names, "Free Tagged"

      get api_v1_teambuilds_path(q: "free tagged"), headers: auth_headers(@owner)
      assert_equal ["Free Tagged"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      mine = response.parsed_body["teambuilds"].find { |entry| entry["sourceId"] == doc["id"] }
      assert_equal ["meta", "GvG", "guild name"], mine["tags"]
    end
```

- [ ] **Step 6: Vérifier le vert puis commit**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: PASS

```bash
git add app/services/teambuilds/validator.rb app/services/teambuilds/indexer.rb \
        test/services/teambuilds/validator_test.rb test/controllers/api/v1/teambuilds_controller_test.rb
git commit -m "feat(api): accepte les tags libres bornés (invalid_tag remplace forbidden_tag)"
```

---

### Task 2: `documentHash` dans les summaries + ETag fort sur GET show

**Files:**
- Modify: `app/models/teambuild.rb:75-90`
- Modify: `app/controllers/api/v1/teambuilds_controller.rb:33-39`
- Test: `test/controllers/api/v1/teambuilds_controller_test.rb`

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter dans `test/controllers/api/v1/teambuilds_controller_test.rb` :

```ruby
    test "summaries expose documentHash and show sets a strong ETag" do
      hash = Teambuild.last.document_hash

      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_equal hash, response.parsed_body["teambuilds"].sole["documentHash"]

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_equal hash, response.parsed_body["teambuilds"].sole["documentHash"]

      get api_v1_teambuild_path(@document["id"]), headers: auth_headers(@owner)
      assert_response :success
      assert_equal %("#{hash}"), response.headers["ETag"]
    end
```

- [ ] **Step 2: Rouge**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb -n /documentHash/`
Expected: FAIL (`documentHash` absent du summary)

- [ ] **Step 3: Implémenter**

Dans `app/models/teambuild.rb`, ajouter `documentHash` au summary (après `updatedAt`) :

```ruby
  def summary
    {
      id: id,
      sourceId: source_uuid,
      name: name,
      author: player&.username,
      tags: tags,
      gameMode: game_mode,
      playerCount: player_count,
      visibility: visibility,
      status: status,
      characters: teambuild_characters.map(&:summary),
      createdAt: created_at,
      updatedAt: updated_at,
      documentHash: document_hash
    }
  end
```

Dans `app/controllers/api/v1/teambuilds_controller.rb`, action `show` :

```ruby
  def show
    teambuild = resolve_teambuild(params[:id])
    return head :not_found if teambuild.nil?
    return head :forbidden unless teambuild.visible_to?(@player)

    response.set_header("ETag", %("#{teambuild.document_hash}"))
    render json: teambuild.document.merge(author: teambuild.player&.username)
  end
```

(On pose le header manuellement plutôt que via `fresh_when` : il faut un ETag fort égal exactement au hash, pas un ETag faible combiné.)

- [ ] **Step 4: Vert + commit**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: PASS

```bash
git add app/models/teambuild.rb app/controllers/api/v1/teambuilds_controller.rb \
        test/controllers/api/v1/teambuilds_controller_test.rb
git commit -m "feat(api): expose documentHash dans les summaries et pose un ETag fort sur GET show"
```

---

### Task 3: Verrou optimiste `If-Match` → 412 sur le PUT

**Files:**
- Modify: `app/services/teambuilds/ingest.rb` (tout le fichier)
- Modify: `app/controllers/api/v1/teambuilds_controller.rb:41-71`
- Test: `test/controllers/api/v1/teambuilds_controller_test.rb`
- Test: `test/services/teambuilds/ingest_test.rb`

- [ ] **Step 1: Tests contrôleur (TDD rouge)**

Étendre le helper `put_doc` dans `test/controllers/api/v1/teambuilds_controller_test.rb` :

```ruby
    def put_doc(player, doc, visibility: nil, status: nil, if_match: nil)
      query = { visibility: visibility, status: status }.compact
      path = api_v1_teambuild_path(doc["id"])
      path += "?#{query.to_query}" unless query.empty?
      headers = json_headers(player)
      headers["If-Match"] = if_match if if_match
      put path, params: doc.to_json, headers: headers
    end
```

Ajouter les tests :

```ruby
    test "upsert honors If-Match optimistic locking" do
      etag = %("#{Teambuild.last.document_hash}")

      put_doc(@owner, @document, if_match: etag)
      assert_response :success

      changed = JSON.parse(@document.to_json)
      changed["name"] = "GvG Split v3"
      put_doc(@owner, changed, if_match: etag)
      assert_response :success
      new_etag = Teambuild.last.reload.document_hash
      assert_not_equal etag.delete('"'), new_etag

      put_doc(@owner, @document, if_match: etag)
      assert_response :precondition_failed
      codes = response.parsed_body["errors"].map { |error| error["code"] }
      assert_includes codes, "precondition_failed"

      put_doc(@owner, changed, if_match: new_etag)
      assert_response :success
    end

    test "upsert If-Match tolerates unquoted values and star on existing builds" do
      put_doc(@owner, @document, if_match: Teambuild.last.document_hash)
      assert_response :success

      put_doc(@owner, @document, if_match: "*")
      assert_response :success
    end

    test "upsert rejects If-Match when the build does not exist yet" do
      fresh = JSON.parse(@document.to_json)
      fresh["id"] = "eeeeeee3-0000-0000-0000-000000000001"
      put_doc(@owner, fresh, if_match: "*")
      assert_response :precondition_failed
      assert_nil Teambuild.find_by(source_uuid: fresh["id"])
    end
```

- [ ] **Step 2: Rouge**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb -n "/If-Match|optimistic/"`
Expected: FAIL — `If-Match` ignoré, 200/201 renvoyés au lieu de 412.

- [ ] **Step 3: Étendre le service Ingest**

Réécrire `app/services/teambuilds/ingest.rb` :

```ruby
module Teambuilds
  class Ingest
    Result = Data.define(:ok?, :teambuild, :errors, :created?, :changed?, :precondition_failed?)

    def self.call(player:, source_uuid:, document:, visibility: "private", status: nil, if_match: nil)
      new(player: player, source_uuid: source_uuid, document: document,
          visibility: visibility, status: status, if_match: if_match).call
    end

    def initialize(player:, source_uuid:, document:, visibility:, status:, if_match:)
      @player = player
      @source_uuid = source_uuid.to_s.downcase
      @document = document
      @visibility = Teambuild::VISIBILITIES.include?(visibility) ? visibility : "private"
      @status = Teambuild::STATUSES.include?(status) ? status : nil
      @if_match = normalize_if_match(if_match)
    end

    def call
      errors = Validator.validate(@document)
      return failure(errors) if errors.any?
      unless UUID_RE.match?(@source_uuid)
        return failure([{ "path" => "$", "code" => "invalid_source_uuid",
                          "message" => "L'identifiant doit être un UUID canonique minuscule" }])
      end

      ActiveRecord::Base.transaction do
        existing = @player.teambuilds.find_by(source_uuid: @source_uuid)
        incoming_hash = DocumentHash.of(@document)

        if @if_match && !etag_matches?(existing)
          return failure([{ "path" => "$", "code" => "precondition_failed",
                            "message" => "If-Match ne correspond pas à l'état actuel du build" }],
                         precondition_failed: true)
        end

        if existing && existing.document_hash == incoming_hash
          existing.update_column(:visibility, @visibility) if existing.visibility != @visibility
          existing.update_column(:status, @status) if @status && existing.status != @status
          return success(existing, false, false)
        end

        created = existing.nil?
        teambuild = existing || @player.teambuilds.new(source_uuid: @source_uuid)
        teambuild.document = @document
        teambuild.visibility = @visibility
        teambuild.status = @status if @status
        Indexer.call(teambuild)
        teambuild.save!
        success(teambuild, created, true)
      end
    end

    private

    UUID_RE = Validator::UUID_RE

    def normalize_if_match(value)
      return unless value.is_a?(String) && value.present?
      value = value.strip
      return "*" if value == "*"
      value.delete_prefix('"').delete_suffix('"')
    end

    def etag_matches?(existing)
      return false if existing.nil?
      return true if @if_match == "*"
      existing.document_hash == @if_match
    end

    def failure(errors, precondition_failed: false)
      Result.new(false, nil, errors, false, false, precondition_failed)
    end

    def success(teambuild, created, changed)
      Result.new(true, teambuild, [], created, changed, false)
    end
  end
end
```

Le check If-Match précède délibérément le no-op : un If-Match obsolète doit échouer même si le payload entrant serait identique.

- [ ] **Step 4: Câbler le contrôleur**

Dans `app/controllers/api/v1/teambuilds_controller.rb`, action `update` :

```ruby
  def update
    return render_invalid_source_uuid unless valid_source_uuid?

    document = parse_document
    return if performed?

    result = begin
      Teambuilds::Ingest.call(
        player: @player,
        source_uuid: source_uuid_param,
        document: document,
        visibility: params[:visibility],
        status: params[:status],
        if_match: if_match_param
      )
    rescue ActiveRecord::RecordNotUnique
      Teambuilds::Ingest.call(
        player: @player,
        source_uuid: source_uuid_param,
        document: document,
        visibility: params[:visibility],
        status: params[:status],
        if_match: if_match_param
      )
    end

    if result.ok?
      payload = result.teambuild.summary.merge(created: result.created?, changed: result.changed?)
      render json: payload, status: result.created? ? :created : :ok
    elsif result.precondition_failed?
      render json: { errors: result.errors }, status: :precondition_failed
    else
      render json: { errors: result.errors }, status: :unprocessable_entity
    end
  end
```

Et dans la section `private` (après `render_invalid_source_uuid`) :

```ruby
  def if_match_param
    request.headers["If-Match"].presence
  end
```

(La normalisation quotes/`*` vit dans `Ingest#normalize_if_match` — le contrôleur ne fait que transmettre.)

- [ ] **Step 5: Vert**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb test/services/teambuilds/ingest_test.rb`
Expected: PASS (les tests ingest existants restent verts — `if_match` a une valeur par défaut `nil`).

Si `ingest_test.rb` reste vert tel quel (`if_match` a `nil` par défaut), ajouter simplement deux tests unitaires dédiés à la fin du fichier :

```ruby
    test "flags precondition_failed on a stale If-Match" do
      ingest(@doc)
      result = Ingest.call(
        player: @owner, source_uuid: @doc["id"],
        document: JSON.parse(@doc.to_json).merge("name" => "x"),
        if_match: "0" * 64
      )
      assert_not result.ok?
      assert result.precondition_failed?
    end

    test "accepts a matching If-Match and star" do
      ingest(@doc)
      hash = @owner.teambuilds.sole.document_hash
      result = Ingest.call(player: @owner, source_uuid: @doc["id"], document: @doc, if_match: hash)
      assert result.ok?
      result = Ingest.call(player: @owner, source_uuid: @doc["id"], document: @doc, if_match: "*")
      assert result.ok?
    end
```

(le helper `ingest` et `@owner` du setup existant sont réutilisés tels quels.)

- [ ] **Step 6: Commit**

```bash
git add app/services/teambuilds/ingest.rb app/controllers/api/v1/teambuilds_controller.rb \
        test/controllers/api/v1/teambuilds_controller_test.rb test/services/teambuilds/ingest_test.rb
git commit -m "feat(api): verrou optimiste If-Match/412 sur l'upsert (optionnel, basé sur document_hash)"
```

---

### Task 4: Filtre `updated_since` (liste + export)

**Files:**
- Modify: `app/models/teambuild.rb` (scopes, ~ligne 55)
- Modify: `app/controllers/api/v1/teambuilds_controller.rb:12-31,125-136`
- Test: `test/controllers/api/v1/teambuilds_controller_test.rb`

- [ ] **Step 1: Test (TDD rouge)**

Ajouter dans `test/controllers/api/v1/teambuilds_controller_test.rb` :

```ruby
    test "updated_since filters index and export" do
      old_doc = JSON.parse(@document.to_json)
      old_doc["id"] = "eeeeeee4-0000-0000-0000-000000000001"
      old_doc["name"] = "Old Split"
      put_doc(@other, old_doc, visibility: "public")
      Teambuild.find_by(source_uuid: old_doc["id"]).update_column(:updated_at, 2.hours.ago)

      fresh_doc = JSON.parse(@document.to_json)
      fresh_doc["id"] = "eeeeeee4-0000-0000-0000-000000000002"
      fresh_doc["name"] = "Fresh Split"
      put_doc(@other, fresh_doc, visibility: "public")

      cutoff = 1.hour.ago.iso8601

      get api_v1_teambuilds_path(updated_since: cutoff), headers: auth_headers(@owner)
      names = response.parsed_body["teambuilds"].map { |t| t["name"] }
      assert_includes names, "Fresh Split"
      assert_not_includes names, "Old Split"

      get export_api_v1_teambuilds_path(updated_since: cutoff), headers: auth_headers(@owner)
      ids = response.parsed_body["teambuilds"].map { |t| t["sourceId"] }
      assert_includes ids, "eeeeeee4-0000-0000-0000-000000000002"
      assert_not_includes ids, old_doc["id"]
    end

    test "updated_since rejects malformed and blank values with 400" do
      get api_v1_teambuilds_path(updated_since: "yesterday"), headers: auth_headers(@owner)
      assert_response :bad_request
      assert_equal "invalid_updated_since", response.parsed_body["errors"].sole["code"]

      get export_api_v1_teambuilds_path(updated_since: ""), headers: auth_headers(@owner)
      assert_response :bad_request

      get api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_response :success
    end
```

- [ ] **Step 2: Rouge**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb -n "/updated_since/"`
Expected: FAIL — le paramètre est ignoré (200 partout).

- [ ] **Step 3: Scope modèle**

Dans `app/models/teambuild.rb`, ajouter après `scope :with_game_mode` :

```ruby
  scope :with_updated_since, ->(time) { where(updated_at: time..) }
```

- [ ] **Step 4: Contrôleur**

Dans `app/controllers/api/v1/teambuilds_controller.rb` :

Ligne 3, ajouter le before_action :

```ruby
  before_action :verify_api_token
  before_action :check_updated_since, only: %i[index export]
```

Garder-fou en tête des actions `index` et `export` (le paramètre invalide a déjà rendu la réponse) :

```ruby
  def index
    return if performed?

    relation = filtered(Teambuild.visible_to(@player))
    ...
  end

  def export
    return if performed?

    records = filtered(Teambuild.visible_to(@player))
    ...
  end
```

Brancher dans `filtered` (avant `relation` final, par exemple après la ligne `with_status`) :

```ruby
    relation = relation.with_updated_since(@updated_since) if @updated_since
```

Et dans `private` :

```ruby
  def check_updated_since
    return unless request.query_parameters.key?("updated_since")

    @updated_since =
      begin
        Time.iso8601(params[:updated_since].to_s)
      rescue ArgumentError
        render json: { errors: [{ "path" => "$", "code" => "invalid_updated_since",
                                  "message" => "updated_since doit être une date-heure ISO 8601" }] },
               status: :bad_request
        nil
      end
  end
```

Sémantique : absent → pas de filtre ; présent mais vide ou malformé → 400 ; date future acceptée (résultat vide).

- [ ] **Step 5: Vert + commit**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: PASS

```bash
git add app/models/teambuild.rb app/controllers/api/v1/teambuilds_controller.rb \
        test/controllers/api/v1/teambuilds_controller_test.rb
git commit -m "feat(api): filtre updated_since (ISO 8601 strict, 400 sinon) sur liste et export"
```

---

### Task 5: Spécifications rswag structurelles + régénération du YAML

Tous les changements doc structuraux, en anglais direct (la traduction complète des textes restants arrive en Task 6). Les nouveaux blocs sont déjà écrits en anglais.

**Files:**
- Modify: `spec/swagger_helper.rb` (schemas/components uniquement)
- Modify: `spec/requests/api/v1/teambuilds_spec.rb`
- Regenerate: `docs/openapi/teambuilds.yaml`

- [ ] **Step 1: Corriger les 5 `nullable` dans `swagger_helper.rb`**

OpenAPI 3.1 : type-array, plus `nullable`. Dans `TeambuildCharacterSummary` (lignes 84-88) :

```ruby
          TeambuildCharacterSummary: {
            type: :object,
            properties: {
              name: { type: :string },
              primaryProfession: { type: ['integer', 'null'], description: 'GW1 id 0-10' },
              secondaryProfession: { type: ['integer', 'null'] },
              eliteSkillId: { type: ['integer', 'null'], description: 'Official GW1 skill id' },
              assignment: { type: :string },
              dominantAttribute: { type: ['string', 'null'] }
            }
          },
```

Dans `ZcxCharacter` (ligne 198) :

```ruby
              equipment: { type: [:object, 'null'], additionalProperties: true },
```

- [ ] **Step 2: Mettre à jour les schemas dans `swagger_helper.rb`**

a) Enum des codes d'erreur (`ErrorList`, ligne 71-72) — `forbidden_tag` disparaît, `invalid_tag`, `precondition_failed`, `invalid_updated_since` entrent :

```ruby
                    code: {
                      type: :string,
                      enum: %w[malformed_json invalid_source_uuid invalid_updated_since not_an_object wrong_case null_array
                               duplicate_attribute_id invalid_skill_ids too_many_characters max_depth invalid_tag reserved_key precondition_failed]
                    },
```

b) `TeambuildSummary` : ajouter `documentHash` après `updatedAt` :

```ruby
              createdAt: { type: :string, format: :'date-time' },
              updatedAt: { type: :string, format: :'date-time' },
              documentHash: {
                type: :string,
                description: 'Hex SHA-256 of the canonicalized stored document (updatedAt excluded). Send it quoted as If-Match on PUT.'
              }
```

c) `ZcxDocument.tags` : les tags deviennent libres (lignes 143-147) :

```ruby
              tags: {
                type: :array,
                maxItems: 24,
                items: { type: :string, maxLength: 64 },
                description: 'Free-form labels. The nine canonical values (GvG HA RA TA AB FA JQ PvP PvE, case-insensitive) are normalized and feed search filters; other labels are preserved verbatim.'
              },
```

d) La limite `max_depth` est documentée dans la description du PUT (bloc suivant, phrase « Nesting limit enforced by max_depth… »). Aucune autre zone n'est à modifier.

- [ ] **Step 3: GET show — documenter l'en-tête ETag (dans `teambuilds_spec.rb`)**

Dans le bloc `get 'Récupérer un teambuild complet'` → `response(200, ...)`, ajouter la documentation d'en-tête (au même niveau que `schema`, à l'intérieur du response 200) — la description reste en français pour l'instant, sa traduction est prévue en Task 6 :

```ruby
        headers: {
          'ETag': {
            description: 'Strong entity tag: quoted SHA-256 document hash. Use it as If-Match on PUT.',
            schema: { type: :string }
          }
        },
```

- [ ] **Step 4: PUT — paramètre `If-Match`, description uuid-only, réponse 412**

Dans le bloc `put` de `'/api/v1/teambuilds/{id}'`, remplacer la description et ajouter le header parameter :

```ruby
    put 'Créer ou remplacer un teambuild (sync fichier par fichier)' do
      produces 'application/json'
      consumes 'application/json'
      description <<~DESC.squish
        Body is the raw .zcx document. Idempotent upsert keyed by (owner, source_uuid):
        create when absent; no-op when the content hash (updatedAt excluded) is unchanged;
        full replace otherwise. Only the lowercase canonical source_uuid is accepted in the
        path — server numeric ids are rejected here (they cannot identify a not-yet-created
        build). visibility and status ride as query params, defaults private/published.
        Optional optimistic locking: send the previously-read documentHash as a quoted
        If-Match header (or * to require existence); on mismatch the write is refused with
        412 and nothing changes. Nesting limit enforced by max_depth: a root character sits
        at depth 0 and any node deeper than 64 levels is rejected.
      DESC

      parameter name: :id, in: :path, required: true, schema: { type: :string, format: :uuid },
                description: 'Lowercase canonical source_uuid only'
      parameter name: :'If-Match', in: :header, required: false, getter: :if_match,
                schema: { type: :string },
                description: 'Optional optimistic lock: quoted documentHash from a previous read, or * to require existence'
```

Ajouter les lets (avec les autres `let(:...)` du bloc put) :

```ruby
      let(:if_match) { nil }
```

Ajouter la réponse 412 (après le response 200) :

```ruby
      response(412, 'Precondition failed (stale If-Match)') do
        before do
          @owner = create_api_player
          seed_build(@owner, zcx_variant(id))
        end
        let(:document) { zcx_variant(id, name: 'GvG Split v2') }
        let(:if_match) { '"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"' }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |error| error['code'] }
          expect(codes).to include('precondition_failed')
        end
      end
```

- [ ] **Step 5: Paramètre `updated_since` sur GET liste + GET export + réponse 400**

Bloc `path '/api/v1/teambuilds'` (GET liste), avec les autres parameters :

```ruby
      parameter name: :updated_since, in: :query, required: false,
                schema: { type: :string, format: :'date-time' },
                description: 'ISO 8601 instant; only builds updated at or after it are returned'
```

avec ses lets :

```ruby
      let(:updated_since) { nil }
```

et la réponse 400 (après le response 200) :

```ruby
      response(400, 'Malformed updated_since') do
        before { @owner = create_api_player }
        let(:updated_since) { 'yesterday' }

        schema({ '$ref': '#/components/schemas/ErrorList' })

        run_test! do |response|
          codes = JSON.parse(response.body)['errors'].map { |e| e['code'] }
          expect(codes).to include('invalid_updated_since')
        end
      end
```

Même ajout (parameter + `let(:updated_since) { nil }` + response 400 identique) dans le bloc `path '/api/v1/teambuilds/export'`.

- [ ] **Step 6: Régénérer le YAML et vérifier**

Run: `bundle exec rake rswag:specs:swaggerize`
Expected: `docs/openapi/teambuilds.yaml` régénéré sans erreur.

```bash
grep -n "nullable" docs/openapi/teambuilds.yaml; echo "exit=$?"
grep -n "forbidden_tag" docs/openapi/teambuilds.yaml; echo "exit=$?"
grep -cn "precondition_failed\|updatedSince\|updated_since\|documentHash" docs/openapi/teambuilds.yaml
```
Expected: aucune occurrence `nullable` ni `forbidden_tag` ; plusieurs occurrences des nouveaux éléments.

Run: `bundle exec rspec spec/requests/api/v1/teambuilds_spec.rb`
Expected: tous les exemples PASS (y compris 412 et 400).

- [ ] **Step 7: Commit**

```bash
git add spec/swagger_helper.rb spec/requests/api/v1/teambuilds_spec.rb
git add -f docs/openapi/teambuilds.yaml
git commit -m "docs(api): aligne la spec OpenAPI 3.1 (nullable, documentHash, If-Match/412, updated_since)"
```

---

### Task 6: Traduction anglaise intégrale de la documentation `/api-docs`

Tout texte français restant de `swagger_helper.rb` et `teambuilds_spec.rb` passe en anglais, puis régénération.

**Files:**
- Modify: `spec/swagger_helper.rb`
- Modify: `spec/requests/api/v1/teambuilds_spec.rb`
- Regenerate: `docs/openapi/teambuilds.yaml`

- [ ] **Step 1: Traduire `swagger_helper.rb`**

a) `info.description` (lignes 18-22) :

```ruby
        description: <<~DESC.squish
          The GWRank teambuild library API for Z-Codex. The payload is a .zcx document as normatively
          defined by docs/zcx_format.md (Z-Codex 1.2.0, version 18). Keys are strictly camelCase.
          Skill ids unknown to the catalog are preserved as-is (never normalized to zero).
        DESC
```

b) Réponses partagées (lignes 32-49) :

```ruby
          Unauthorized: { description: 'Missing or invalid token' },
          Forbidden: { description: "Someone else's private build, or unauthorized write" },
          BadRequest: {
            description: 'Malformed JSON or invalid identifier',
            content: {
              'application/json' => {
                schema: { '$ref': '#/components/schemas/ErrorList' }
              }
            }
          },
          Invalid: {
            description: 'Format rule violation (see docs/zcx_format.md §11)',
            content: {
              'application/json' => {
                schema: { '$ref': '#/components/schemas/ErrorList' }
              }
            }
          }
```

c) Descriptions de champs restantes :

```ruby
              primaryProfession: { type: ['integer', 'null'], description: 'GW1 id 0-10' },
```
(déjà fait en Task 5 — vérifier seulement) ; `ZcxDocument` (lignes 134-138) :

```ruby
            description: <<~DESC.squish,
              The complete .zcx document — see docs/zcx_format.md as the normative reference.
              Known fields are typed below; any extra field is tolerated and preserved verbatim
              (future versions of the format).
            DESC
```

`version` (ligne 140) :

```ruby
              version: { type: :integer, description: 'Informative, never routed' },
```

`skillIds` (ligne 183) :

```ruby
                 description: 'Slots 0-7; 0 = empty. Official GW1 ids, unknown ones tolerated.'
```

`attributes` (ligne 195) :

```ruby
                 description: "ids unique within a single character (otherwise rejected with 422)"
```

Exemple (ligne 208) :

```ruby
          GvgSplit: {
            summary: 'Single-character teambuild with variant/lock/spike (format §12)',
```

Aussi ligne 245 : `notes: 'Élémentaliste eau & dégén.'` → `notes: 'Water elementalist & degeneration.'`

- [ ] **Step 2: Traduire `teambuilds_spec.rb`**

Titres et descriptions — remplacer chaque bloc :

```ruby
    get 'Search teambuilds' do
      produces 'application/json'
      description <<~DESC.squish
        Paginated list of summaries of everything the caller can see:
        publics + their own, including others' public drafts.
      DESC
```

Paramètres de la liste :

```ruby
      parameter name: :q, in: :query, schema: { type: :string }, description: 'Name, case-insensitive'
      parameter name: 'tags[]', in: :query, getter: :tag_filters,
                schema: { type: :array, items: { type: :string } }, description: 'Array overlap'
      parameter name: :profession_id, in: :query, schema: { type: :integer },
                description: 'Official GW1 profession code (0-10)'
      parameter name: :elite_skill_id, in: :query, schema: { type: :integer },
                description: 'Official GW1 skill id'
```

Réponses de tous les endpoints — table de correspondance appliquée partout :

| Français | Anglais |
|---|---|
| `'Liste paginée de résumés'` | `'Paginated list of summaries'` |
| `'Token absent ou invalide'` | `'Missing or invalid token'` |
| `'Exporter tous les teambuilds visibles en un appel'` | `'Export all visible teambuilds in one call'` |
| description export | `'Enriched summaries carrying the complete .zcx document for everything the caller can see: publics + their own, including public drafts (filterable via status). Single response, no pagination.'` |
| `'Liste complète des teambuilds visibles'` | `'Every visible teambuild'` |
| `'Récupérer un teambuild complet'` | `'Fetch one full teambuild'` |
| description show | `'Returns the stored .zcx document, intact, merged with a root-level author key (owner account name). Accepts the server id or the source_uuid (the .zcx id). Key order may differ from the original; semantic content is identical. Responds with a strong ETag header equal to the quoted documentHash.'` |
| `'Document .zcx complet'` | `'Complete .zcx document'` |
| `'Id serveur ou source_uuid canonique minuscule'` | `'Server id or lowercase canonical source_uuid'` |
| `'Introuvable'` | `'Not found'` |
| `"Build privé d'autrui ou écriture non autorisée"` | `"Someone else's private build, or unauthorized write"` |
| `'Créé'` | `'Created'` |
| `'Remplacé ou inchangé (voir created/changed)'` | `'Replaced or unchanged (see created/changed)'` |
| `'JSON malformé ou identifiant invalide'` | `'Malformed JSON or invalid identifier'` |
| `'Violation des règles du format (cf. docs/zcx_format.md §11)'` | `'Format rule violation (see docs/zcx_format.md §11)'` |
| `'Supprimer un de ses teambuilds'` | `'Delete one of your own teambuilds'` |
| `'Supprimé'` | `'Deleted'` |

Schémas inline : `author` apparaît deux fois (swagger_helper ligne 97 et spec ligne 174) :

```ruby
author: { type: :string, description: "Owner account name (@username without the @)" }
```

- [ ] **Step 3: Balayage anti-français**

```bash
grep -nP "[àâäçéèêëîïôöùûüÿœ]" spec/swagger_helper.rb spec/requests/api/v1/teambuilds_spec.rb || echo CLEAN
```
Expected: `CLEAN` (les messages runtime FR dans `app/` sont volontairement conservés). Si des occurrences subsistent dans ces deux fichiers, les traduire pareillement. Exception tolérée : `seed_build` raise interne (jamais rendu dans la doc).

- [ ] **Step 4: Régénérer + tests + commit**

Run: `bundle exec rake rswag:specs:swaggerize && bundle exec rspec spec/requests/api/v1/teambuilds_spec.rb`
Expected: YAML régénéré en anglais, tous les specs PASS.

```bash
git add spec/swagger_helper.rb spec/requests/api/v1/teambuilds_spec.rb
git add -f docs/openapi/teambuilds.yaml
git commit -m "docs(api): translate the OpenAPI documentation served at /api-docs into English"
```

---

### Task 7: Chiffrer `max_depth` dans `zcx_format.md`

**Files:**
- Modify: `docs/zcx_format.md` (~ligne 148-151, §5)

- [ ] **Step 1: Localiser et corriger**

Run: `grep -n "sans limite" docs/zcx_format.md`
Expected: une occurrence ligne ~151 dans la parenthèse décrivant l'arbre récursif.

Remplacer `(…récursif sans limite de profondeur)` par :

```
(récursif ; profondeur maximale imposée côté ingestion GWRank : chaque personnage racine est à la profondeur 0 et tout nœud au-delà de 64 niveaux est rejeté — erreur API `max_depth`)
```

- [ ] **Step 2: Commit**

```bash
git add docs/zcx_format.md
git commit -m "docs(zcx): chiffre la profondeur maximale des variants (64 niveaux, erreur max_depth)"
```

---

### Task 8: Vérification finale

- [ ] **Step 1: Toutes les suites**

```bash
bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb \
               test/services/teambuilds/validator_test.rb \
               test/services/teambuilds/ingest_test.rb \
               test/services/teambuilds/indexer_test.rb \
               test/models/teambuild_test.rb
bundle exec rspec spec/requests/api/v1/teambuilds_spec.rb
```
Expected: tout PASS.

- [ ] **Step 2: Cohérence doc ↔ code**

```bash
grep -n "nullable:" docs/openapi/teambuilds.yaml || echo "OK: no nullable"
grep -rn "forbidden_tag" app/ spec/ docs/openapi/ || echo "OK: no forbidden_tag"
grep -n "MAX_DEPTH = 64" app/services/teambuilds/validator.rb
grep -n "maxItems: 24" docs/openapi/teambuilds.yaml
```
Expected: OK partout ; `max_depth = 64` présent dans le code et documenté ; enum tags libre (maxLength 64, maxItems 24) dans le YAML.

- [ ] **Step 3: Smoke local (serveur lancé)**

```bash
rails s -d  # si nécessaire
TOKEN=$(bin/rails runner "print Player.first.api_token")
curl -si http://localhost:3000/api/v1/teambuilds/$UUID -H "Authorization: Bearer $TOKEN" | grep -i etag
curl -si "http://localhost:3000/api/v1/teambuilds?updated_since=not-a-date" -H "Authorization: Bearer $TOKEN" | head -1
```
Expected: `ETag: "<64 hex>"` ; seconde requête → `HTTP/1.1 400 Bad Request`.

- [ ] **Step 4: Mise à jour tasks/todo.md (section review) + réponse à Philippe**

Rédiger la réponse aux retours : point 1 déjà livré (commit `7d114fd1`, à déployer), points 2-5 livrés ici, avec le tableau demandes→état. Ne pas envoyer sans validation d'Arka.
