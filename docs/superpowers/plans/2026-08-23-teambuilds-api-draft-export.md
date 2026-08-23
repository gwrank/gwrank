# API Teambuilds : export global, statut draft, variants indexés, tags fermés — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implémenter la spec `docs/superpowers/specs/2026-08-23-teambuilds-api-draft-export-design.md` : endpoint d'export JSON global, statut `draft|published` indépendant de la visibilité, indexation des personnages des variants, liste fermée de tags imposée par le validateur.

**Architecture:** Extension de l'API v1 existante (`Api::V1::TeambuildsController`, services `Teambuilds::{Validator,Ingest,Indexer}`, modèle `Teambuild`). Nouvelle colonne `status`, nouvelle action de collection `export`, parcours récursif de l'arbre de variants dans l'Indexer, règles supplémentaires dans le Validator. Contrat OpenAPI mis à jour (`docs/openapi/teambuilds.yaml`).

**Tech Stack:** Rails 8.1, Ruby 3.4, Minitest, PostgreSQL (jsonb, index GIN), OpenAPI 3.1.

---

## Notes transversales (à lire avant de commencer)

- **Arbre de travail sale** : le dépôt contient déjà des modifications non committées sans rapport avec ce plan (`app/services/discord_bot/**`, `test/fixtures/skills.yml`, `test/services/discord_bot/**`, blocs d'annotation sur `app/models/teambuild*.rb` et `test/models/teambuild_test.rb`). À chaque commit, ne stage **que** les fichiers listés dans la tâche.
- **Style des messages de commit** : Conventional Commits en anglais, comme l'existant (`feat(api): …`, `fix(services): …`).
- **Tests** : Minitest. Lancer un fichier : `bin/rails test test/path/to/file_test.rb`. Suite entière : `bin/rails test`. Attendu à chaque fin de tâche : « 0 failures, 0 errors ».
- Les messages d'erreur du domaine sont en français, comme l'existant.
- `Teambuilds::Validator::UUID_RE`, `DocumentHash`, `load_zcx` (fixture `gvg_split`) et les helpers `create_player` / `auth_headers` existent déjà dans `test/test_helper.rb`.

## Structure de fichiers

| Action | Fichier | Responsabilité |
|---|---|---|
| Create | `db/migrate/20260823090000_add_status_to_teambuilds.rb` | Colonne `status` + index |
| Modify | `app/models/teambuild.rb` | Constantes, scopes, validation, `summary`, `export_summary` |
| Modify | `app/services/teambuilds/validator.rb` | Tags fermés, cap 512 personnages aplatis |
| Modify | `app/services/teambuilds/indexer.rb` | Aplatissement des variants, tags canoniques |
| Modify | `app/services/teambuilds/ingest.rb` | Paramètre `status` |
| Modify | `config/routes.rb` | Route collection `export` |
| Modify | `app/controllers/api/v1/teambuilds_controller.rb` | `export`, filtre `status=`, passage du statut au service |
| Modify | `app/views/builds/index.html.erb`, `app/views/builds/show.html.erb` | Badge « Draft » |
| Modify | `docs/openapi/teambuilds.yaml` | Contrat |
| Modify | `db/schema.rb` | Régénéré par la migration |
| Test | `test/models/teambuild_test.rb`, `test/services/teambuilds/{validator,indexer,ingest}_test.rb`, `test/controllers/api/v1/teambuilds_controller_test.rb`, `test/controllers/builds_controller_test.rb` | Tests TDD |

---

### Task 1: Migration et modèle — colonne `status`

**Files:**
- Create: `db/migrate/20260823090000_add_status_to_teambuilds.rb`
- Modify: `app/models/teambuild.rb`
- Modify: `test/models/teambuild_test.rb`
- Modify: `db/schema.rb` (régénéré)

- [ ] **Step 1: Écrire le test qui échoue**

Dans `test/models/teambuild_test.rb`, ajouter à l'intérieur de `class TeambuildTest` :

```ruby
  test "status defaults to published and rejects unknown values" do
    player = create_player
    build = Teambuild.new(player: player, source_uuid: SecureRandom.uuid, document: {})
    assert_equal "published", build.status
    build.status = "brouillon"
    refute build.valid?
  end

  test "draft and published scopes filter by status" do
    player = create_player
    draft = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {}, status: "draft")
    published = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {})

    assert_equal [draft.id], Teambuild.draft.map(&:id)
    assert_includes Teambuild.published.map(&:id), published.id
    assert_not_includes Teambuild.published.map(&:id), draft.id
    assert_equal [draft.id], Teambuild.with_status("draft").map(&:id)
  end

  test "summary exposes status" do
    player = create_player
    teambuild = Teambuild.create!(player: player, source_uuid: SecureRandom.uuid, document: {})
    assert_equal "published", teambuild.summary[:status]
  end
```

- [ ] **Step 2: Vérifier que le test échoue**

Run: `bin/rails test test/models/teambuild_test.rb`
Expected: FAIL — `unknown attribute 'status' for Teambuild.` (ou erreur équivalente)

- [ ] **Step 3: Créer la migration**

Create `db/migrate/20260823090000_add_status_to_teambuilds.rb` :

```ruby
class AddStatusToTeambuilds < ActiveRecord::Migration[8.1]
  def change
    add_column :teambuilds, :status, :string, null: false, default: "published"
    add_index :teambuilds, :status
  end
end
```

Run: `bin/rails db:migrate`
Expected: migration appliquée, `db/schema.rb` contient `t.string "status", default: "published", null: false` dans `create_table "teambuilds"`.

- [ ] **Step 4: Implémenter dans le modèle**

Dans `app/models/teambuild.rb` :

Ajouter la constante sous `VISIBILITIES` (ligne 32) :

```ruby
  STATUSES = %w[draft published].freeze
```

Ajouter la validation après celle de `visibility` (ligne 43) :

```ruby
  validates :status, inclusion: { in: STATUSES }
```

Ajouter les scopes après le scope `visible_to` (ligne 48) :

```ruby
  scope :draft, -> { where(status: "draft") }
  scope :published, ->(value = "published") { where(status: value) }
  scope :with_status, ->(value) { where(status: value) }
```

⚠️ Attention : `scope :published` avec argument optionnel est une mauvaise idée (appel `Teambuild.published` ambigu). Utiliser simplement :

```ruby
  scope :draft, -> { where(status: "draft") }
  scope :published, -> { where(status: "published") }
  scope :with_status, ->(value) { where(status: value) }
```

Dans `summary` (ligne 68), ajouter `status:` juste après `visibility:` :

```ruby
      visibility: visibility,
      status: status,
```

- [ ] **Step 5: Rafraîchir les annotations**

Run: `bundle exec annotate`
Expected: les blocs `# == Schema Information` de `app/models/teambuild.rb`, `test/models/teambuild_test.rb` etc. incluent désormais `status`.

- [ ] **Step 6: Vérifier que les tests passent**

Run: `bin/rails test test/models/teambuild_test.rb`
Expected: PASS (10 runs, 0 failures)

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260823090000_add_status_to_teambuilds.rb db/schema.rb app/models/teambuild.rb test/models/teambuild_test.rb
git commit -m "feat(models): add draft/published status to teambuilds"
```

---

### Task 2: Validator — liste fermée de tags

**Files:**
- Modify: `app/services/teambuilds/validator.rb`
- Modify: `test/services/teambuilds/validator_test.rb`
- Modify: `test/fixtures/files/teambuilds/gvg_split.zcx.json` (tag `"meta"` interdit par la nouvelle règle)
- Modify: `test/services/teambuilds/indexer_test.rb:15` (assertion dépendant de la fixture)

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/services/teambuilds/validator_test.rb`, ajouter :

```ruby
    test "rejects tags outside the closed list" do
      @doc["tags"] = ["GvG", "meta"]
      errors = errors_for(@doc)
      assert_equal ["forbidden_tag"], errors.map { |e| e["code"] }
      assert_equal "$.tags", errors.first["path"]
    end

    test "accepts allowed tags case-insensitively" do
      @doc["tags"] = ["gvg", "PvE"]
      assert_empty errors_for(@doc)
    end

    test "rejects non-string tags" do
      @doc["tags"] = ["GvG", 42]
      assert_includes errors_for(@doc).map { |e| e["code"] }, "forbidden_tag"
    end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/services/teambuilds/validator_test.rb`
Expected: FAIL — les nouveaux tests échouent (aucune règle de tag actuellement).

- [ ] **Step 3: Implémenter**

Dans `app/services/teambuilds/validator.rb` :

Ajouter la constante près de `MAX_ROOT_CHARACTERS` (ligne 28) :

```ruby
    ALLOWED_TAGS = %w[GvG HA RA TA AB FA JQ PvP PvE].freeze
```

Dans `call` (ligne 46), ajouter la validation après `reject_null_arrays` :

```ruby
    def call
      check_keys("$", @document, ROOT_KEYS)
      reject_null_arrays("$", @document, %w[tags natureRituals locks spike])
      validate_tags(@document["tags"])
      validate_characters(@document["characters"]) if @document.key?("characters")
      validate_locks(@document["locks"])
      validate_spike(@document["spike"])
      errors
    end
```

Ajouter les méthodes privées (après `reject_null_arrays`, ligne 75) :

```ruby
    def validate_tags(tags)
      return unless tags.is_a?(Array)
      tags.each do |tag|
        next if allowed_tag?(tag)
        add_error("$.tags", "forbidden_tag",
                  %(Tag #{tag.inspect} non autorisé (autorisés : #{ALLOWED_TAGS.join(", ")})))
      end
    end

    def allowed_tag?(tag)
      tag.is_a?(String) && ALLOWED_TAGS.any? { |allowed| allowed.casecmp(tag).zero? }
    end
```

- [ ] **Step 4: Vérifier le passage des tests validateur**

Run: `bin/rails test test/services/teambuilds/validator_test.rb`
Expected: PASS

- [ ] **Step 5: Réparer la fixture et ses dépendances**

Le tag `"meta"` de la fixture de référence est désormais rejeté — tous les tests utilisant `load_zcx` échoueraient.

Dans `test/fixtures/files/teambuilds/gvg_split.zcx.json` ligne 5 :

```json
  "tags": ["GvG"],
```

Dans `test/services/teambuilds/indexer_test.rb` ligne 15 :

```ruby
      assert_equal %w[GvG], @teambuild.tags
```

(Les enregistrements créés directement dans `test/models/teambuild_test.rb:66` avec `tags: ["GvG", "meta"]` ne passent pas par le validateur : ne pas y toucher.)

- [ ] **Step 6: Suite locale services + contrôleurs API**

Run: `bin/rails test test/services/teambuilds/ test/controllers/api/v1/`
Expected: PASS (0 failures)

- [ ] **Step 7: Commit**

```bash
git add app/services/teambuilds/validator.rb test/services/teambuilds/validator_test.rb test/fixtures/files/teambuilds/gvg_split.zcx.json test/services/teambuilds/indexer_test.rb
git commit -m "feat(services): enforce the closed tag list on zcx ingestion"
```

---

### Task 3: Validator — cap de 512 personnages aplatis

**Files:**
- Modify: `app/services/teambuilds/validator.rb`
- Modify: `test/services/teambuilds/validator_test.rb`

- [ ] **Step 1: Écrire le test qui échoue**

Dans `test/services/teambuilds/validator_test.rb`, ajouter :

```ruby
    test "rejects flattened trees over 512 characters including variants" do
      variant = JSON.parse(@doc["characters"][0].to_json)
      variant["variants"] = []
      @doc["characters"] = Array.new(12) { JSON.parse(variant.to_json) }
      @doc["characters"].each do |character|
        43.times { character["variants"] << JSON.parse(variant.to_json) }
      end
      errors = errors_for(@doc)
      code_errors = errors.select { |e| e["code"] == "too_many_characters" }
      assert_equal 1, code_errors.size
      assert_equal "$.characters", code_errors.first["path"]
    end
```

(12 racines × 43 variants = 528 personnages ; profondeur restée à 1, donc le cap `max_depth` n'est pas atteint.)

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/services/teambuilds/validator_test.rb`
Expected: FAIL — aucune erreur levée aujourd'hui pour un arbre large (le cap actuel ne compte que les racines).

- [ ] **Step 3: Implémenter**

Dans `app/services/teambuilds/validator.rb` :

Constante (à côté de `MAX_DEPTH`, ligne 30) :

```ruby
    MAX_TOTAL_CHARACTERS = 512
```

Initialiser le compteur dans `initialize` (ligne 41) :

```ruby
    def initialize(document)
      @document = document
      @errors = []
      @character_count = 0
    end
```

Compter chaque personnage dans `validate_character` (ligne 89), juste après la garde `is_a?(Hash)` :

```ruby
    def validate_character(character, path, depth)
      return unless character.is_a?(Hash)
      if depth > MAX_DEPTH
        return add_error(path, "max_depth", "Arbre de variantes trop profond")
      end
      @character_count += 1
      check_keys(path, character, CHARACTER_KEYS)
      reject_null_arrays(path, character, %w[skillIds attributes activeAttributeBoosts variants])
      validate_skill_ids(path, character["skillIds"])
      validate_attributes(path, character["attributes"])
      validate_equipment(path, character["equipment"])
      Array(character["variants"]).each_with_index do |variant, i|
        validate_character(variant, "#{path}.variants[#{i}]", depth + 1)
      end
    end
```

Contrôler le total **une seule fois**, en fin de `call` :

```ruby
    def call
      check_keys("$", @document, ROOT_KEYS)
      reject_null_arrays("$", @document, %w[tags natureRituals locks spike])
      validate_tags(@document["tags"])
      validate_characters(@document["characters"]) if @document.key?("characters")
      validate_locks(@document["locks"])
      validate_spike(@document["spike"])
      if @character_count > MAX_TOTAL_CHARACTERS
        add_error("$.characters", "too_many_characters",
                  "L'arbre complet (variants compris) dépasse #{MAX_TOTAL_CHARACTERS} personnages")
      end
      errors
    end
```

- [ ] **Step 4: Vérifier le passage**

Run: `bin/rails test test/services/teambuilds/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/teambuilds/validator.rb test/services/teambuilds/validator_test.rb
git commit -m "feat(services): cap flattened zcx character trees at 512"
```

---

### Task 4: Indexer — variants indexés et tags canoniques

**Files:**
- Modify: `app/services/teambuilds/indexer.rb`
- Modify: `test/services/teambuilds/indexer_test.rb`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/services/teambuilds/indexer_test.rb`, ajouter :

```ruby
    test "indexes variant characters after root ones" do
      doc = load_zcx
      variant = JSON.parse(doc["characters"][0].to_json)
      variant["id"] = "22222222-2222-2222-2222-222222222222"
      variant["name"] = "Water Snare Variant"
      variant["skillIds"] = [946, 0, 0, 0, 0, 0, 0, 0]
      variant["variants"] = []
      doc["characters"][0]["variants"] << variant

      @teambuild.document = doc
      Indexer.call(@teambuild)
      @teambuild.save!

      rows = @teambuild.reload.teambuild_characters.order(:position)
      assert_equal 2, rows.count
      assert_equal "Water Snare", rows.first.name
      assert_equal "Water Snare Variant", rows.second.name
      assert_equal skills(:trappers_focus).id, rows.second.elite_skill_id
      assert_equal 1, @teambuild.player_count
    end

    test "canonicalizes and deduplicates tags against the closed list" do
      doc = load_zcx
      doc["tags"] = ["gvg", "PVP", "GvG"]
      @teambuild.document = doc
      Indexer.call(@teambuild)
      assert_equal %w[GvG PvP], @teambuild.tags
    end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/services/teambuilds/indexer_test.rb`
Expected: FAIL — « indexes variant characters… » (1 seule ligne indexée aujourd'hui) et « canonicalizes… » (tags stockés bruts).

- [ ] **Step 3: Implémenter**

Dans `app/services/teambuilds/indexer.rb` :

Remplacer `assign_scalars` et ajouter `canonical_tags` :

```ruby
    def assign_scalars
      @teambuild.name = @document["name"].to_s
      @teambuild.tags = canonical_tags
      @teambuild.game_mode = @document["gameMode"].to_s
      @teambuild.player_count = root_characters.size
      @teambuild.document_hash = DocumentHash.of(@document)
    end

    def canonical_tags
      Array(@document["tags"]).filter_map do |tag|
        Teambuild::ALLOWED_TAGS.find { |allowed| allowed.casecmp(tag.to_s).zero? }
      end.uniq
    end
```

Remplacer `rebuild_characters` et ajouter `indexed_characters` (DFS pré-ordre : personnage, puis ses variants récursivement ; `player_count` reste sur la racine) :

```ruby
    def rebuild_characters
      @teambuild.teambuild_characters.destroy_all
      indexed_characters.each_with_index { |character, position| build_row(character, position) }
    end

    def indexed_characters
      [].tap do |flat|
        walk = lambda do |character|
          flat << character
          Array(character["variants"]).each { |variant| walk.call(variant) if variant.is_a?(Hash) }
        end
        root_characters.each { |character| walk.call(character) }
      end
    end
```

- [ ] **Step 4: Vérifier le passage**

Run: `bin/rails test test/services/teambuilds/indexer_test.rb`
Expected: PASS (6 runs)

- [ ] **Step 5: Commit**

```bash
git add app/services/teambuilds/indexer.rb test/services/teambuilds/indexer_test.rb
git commit -m "feat(services): index variant characters and canonicalize tags"
```

---

### Task 5: Ingest — paramètre `status`

**Files:**
- Modify: `app/services/teambuilds/ingest.rb`
- Modify: `test/services/teambuilds/ingest_test.rb`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/services/teambuilds/ingest_test.rb`, remplacer le helper `ingest` (lignes 10-12) par :

```ruby
    def ingest(document, visibility: "private", status: nil)
      Ingest.call(player: @owner, source_uuid: @doc["id"], document: document,
                  visibility: visibility, status: status)
    end
```

Ajouter les tests :

```ruby
    test "defaults status to published on creation" do
      ingest(@doc)
      assert_equal "published", @owner.teambuilds.sole.status
    end

    test "persists an explicit draft status" do
      result = ingest(@doc, status: "draft")
      assert result.ok?
      assert_equal "draft", @owner.teambuilds.sole.reload.status
    end

    test "applies status changes without flipping changed?" do
      ingest(@doc, status: "draft")
      result = ingest(@doc)
      assert result.ok?
      assert_not result.changed?
      assert_equal "draft", @owner.teambuilds.sole.reload.status

      result = ingest(@doc, status: "published")
      assert_not result.changed?
      assert_equal "published", @owner.teambuilds.sole.reload.status
    end

    test "keeps the current status when replaced without the param" do
      ingest(@doc, status: "draft")
      changed = JSON.parse(@doc.to_json)
      changed["name"] = "GvG Split v2"
      ingest(changed)
      assert_equal "draft", @owner.teambuilds.sole.reload.status
    end

    test "ignores unknown status values" do
      ingest(@doc, status: "draft")
      ingest(@doc, status: "brouillon")
      assert_equal "draft", @owner.teambuilds.sole.reload.status
    end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/services/teambuilds/ingest_test.rb`
Expected: FAIL — `unknown keyword: :status`

- [ ] **Step 3: Implémenter**

Dans `app/services/teambuilds/ingest.rb` :

```ruby
    def self.call(player:, source_uuid:, document:, visibility: "private", status: nil)
      new(player: player, source_uuid: source_uuid, document: document,
          visibility: visibility, status: status).call
    end

    def initialize(player:, source_uuid:, document:, visibility:, status:)
      @player = player
      @source_uuid = source_uuid.to_s.downcase
      @document = document
      @visibility = Teambuild::VISIBILITIES.include?(visibility) ? visibility : "private"
      @status = Teambuild::STATUSES.include?(status) ? status : nil
    end
```

Branche no-op (ligne 28-31) — miroir exact de la visibilité :

```ruby
        if existing && existing.document_hash == incoming_hash
          existing.update_column(:visibility, @visibility) if existing.visibility != @visibility
          existing.update_column(:status, @status) if @status && existing.status != @status
          return success(existing, false, false)
        end
```

Branche création/remplacement (lignes 33-39) :

```ruby
        created = existing.nil?
        teambuild = existing || @player.teambuilds.new(source_uuid: @source_uuid)
        teambuild.document = @document
        teambuild.visibility = @visibility
        teambuild.status = @status if @status
        Indexer.call(teambuild)
        teambuild.save!
        success(teambuild, created, true)
```

(Sémantique spec : `changed?` ne suit que le contenu du document zcx.)

- [ ] **Step 4: Vérifier le passage**

Run: `bin/rails test test/services/teambuilds/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/teambuilds/ingest.rb test/services/teambuilds/ingest_test.rb
git commit -m "feat(services): thread a draft/published status through upserts"
```

---

### Task 6: API — `status` sur l'upsert et filtre de recherche

**Files:**
- Modify: `app/controllers/api/v1/teambuilds_controller.rb`
- Modify: `test/controllers/api/v1/teambuilds_controller_test.rb`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/controllers/api/v1/teambuilds_controller_test.rb`, remplacer le helper `put_doc` (lignes 16-20) par :

```ruby
    def put_doc(player, doc, visibility: nil, status: nil)
      query = { visibility: visibility, status: status }.compact
      path = api_v1_teambuild_path(doc["id"])
      path += "?#{query.to_query}" unless query.empty?
      put path, params: doc.to_json, headers: json_headers(player)
    end
```

Ajouter les tests :

```ruby
    test "upsert accepts a status param and summaries expose it" do
      fresh = JSON.parse(@document.to_json)
      fresh["id"] = "fffffff1-0000-0000-0000-000000000001"
      fresh["name"] = "Draft Split"
      put_doc(@owner, fresh, status: "draft")
      assert_response :created
      assert_equal "draft", response.parsed_body["status"]

      get api_v1_teambuilds_path(status: "draft"), headers: auth_headers(@owner)
      assert_equal ["Draft Split"], response.parsed_body["teambuilds"].map { |t| t["name"] }

      get api_v1_teambuilds_path(status: "published"), headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |t| t["name"] }, "GvG Split"
    end

    test "index ignores invalid status filters" do
      get api_v1_teambuilds_path(status: "brouillon"), headers: auth_headers(@owner)
      assert_response :success
      assert_equal 1, response.parsed_body["pagination"]["totalCount"]
    end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: FAIL — `status` ignoré par l'upsert et le filtre.

- [ ] **Step 3: Implémenter**

Dans `app/controllers/api/v1/teambuilds_controller.rb` :

Passage du statut aux deux appels `Teambuilds::Ingest.call` (lignes 40-45 et 47-52) — ajouter `status: params[:status]` :

```ruby
      result = begin
        Teambuilds::Ingest.call(
          player: @player,
          source_uuid: source_uuid_param,
          document: document,
          visibility: params[:visibility],
          status: params[:status]
        )
      rescue ActiveRecord::RecordNotUnique
        Teambuilds::Ingest.call(
          player: @player,
          source_uuid: source_uuid_param,
          document: document,
          visibility: params[:visibility],
          status: params[:status]
        )
      end
```

Filtre dans `filtered` (ligne 115), avant la ligne `owned_by` :

```ruby
    def filtered(relation)
      relation = relation.with_name_like(params[:q]) if params[:q].present?
      relation = relation.tagged_with_any(params[:tags]) if params[:tags].present?
      relation = relation.with_profession_code(params[:profession_id]) if params[:profession_id].present?
      relation = relation.with_skill_id(params[:elite_skill_id]) if params[:elite_skill_id].present?
      relation = relation.with_campaign(params[:campaign]) if params[:campaign].present?
      relation = relation.with_game_mode(params[:game_mode]) if params[:game_mode].present?
      relation = apply_player_count_range(relation)
      relation = relation.with_status(params[:status]) if Teambuild::STATUSES.include?(params[:status])
      relation = relation.owned_by(@player) if params[:visibility] == "mine"
      relation
    end
```

- [ ] **Step 4: Vérifier le passage**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/teambuilds_controller.rb test/controllers/api/v1/teambuilds_controller_test.rb
git commit -m "feat(api): accept status on upserts and filter search by status"
```

---

### Task 7: API — endpoint d'export global

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/api/v1/teambuilds_controller.rb`
- Modify: `app/models/teambuild.rb`
- Modify: `test/controllers/api/v1/teambuilds_controller_test.rb`

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/controllers/api/v1/teambuilds_controller_test.rb`, ajouter :

```ruby
    test "export requires a token" do
      get export_api_v1_teambuilds_path
      assert_response :unauthorized
    end

    test "export returns visible builds with intact documents" do
      public_doc = JSON.parse(@document.to_json)
      public_doc["id"] = "aaaaaaa1-0000-0000-0000-000000000009"
      put_doc(@other, public_doc, visibility: "public")

      hidden_doc = JSON.parse(@document.to_json)
      hidden_doc["id"] = "aaaaaaa1-0000-0000-0000-000000000008"
      put_doc(@other, hidden_doc)

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_response :success
      entries = response.parsed_body["teambuilds"]
      ids = entries.map { |entry| entry["sourceId"] }
      assert_includes ids, @document["id"]
      assert_includes ids, public_doc["id"]
      assert_not_includes ids, hidden_doc["id"]

      mine = entries.find { |entry| entry["sourceId"] == @document["id"] }
      assert_equal @document, mine["document"]
      assert_equal "published", mine["status"]
      assert_equal 1, mine["playerCount"]
    end

    test "export includes others' public drafts and supports the status filter" do
      draft_doc = JSON.parse(@document.to_json)
      draft_doc["id"] = "bbbbbbb1-0000-0000-0000-000000000007"
      put_doc(@other, draft_doc, visibility: "public", status: "draft")

      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_includes response.parsed_body["teambuilds"].map { |e| e["sourceId"] }, draft_doc["id"]

      get export_api_v1_teambuilds_path(status: "draft"), headers: auth_headers(@owner)
      assert_equal [draft_doc["id"]],
                   response.parsed_body["teambuilds"].map { |e| e["sourceId"] }
    end

    test "export can be empty" do
      Teambuild.destroy_all
      get export_api_v1_teambuilds_path, headers: auth_headers(@owner)
      assert_response :success
      assert_empty response.parsed_body["teambuilds"]
    end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'export_api_v1_teambuilds_path'` (route inexistante).

- [ ] **Step 3: Route**

Dans `config/routes.rb` (lignes 6), remplacer :

```ruby
      resources :teambuilds, only: [:index, :show, :update, :destroy] do
        collection { get :export }
      end
```

- [ ] **Step 4: Modèle — `export_summary`**

Dans `app/models/teambuild.rb`, après `summary` :

```ruby
  def export_summary
    summary.merge(document: document)
  end
```

- [ ] **Step 5: Contrôleur — action `export`**

Dans `app/controllers/api/v1/teambuilds_controller.rb`, après `index` (ligne 23) :

```ruby
  def export
    records = filtered(Teambuild.visible_to(@player))
              .includes(teambuild_characters: [:primary_profession, :secondary_profession, :elite_skill])
              .order(updated_at: :desc)

    render json: { teambuilds: records.map(&:export_summary) }
  end
```

(Réutilise `filtered` : mêmes filtres que la recherche, dont `status=`. Pas de pagination — arbitrage spec.)

- [ ] **Step 6: Vérifier le passage**

Run: `bin/rails test test/controllers/api/v1/teambuilds_controller_test.rb`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/teambuilds_controller.rb app/models/teambuild.rb test/controllers/api/v1/teambuilds_controller_test.rb
git commit -m "feat(api): expose the one-shot teambuilds export endpoint"
```

---

### Task 8: Web UI — badge « Draft »

**Files:**
- Modify: `app/views/builds/index.html.erb`
- Modify: `app/views/builds/show.html.erb`
- Modify: `test/controllers/builds_controller_test.rb`

- [ ] **Step 1: Écrire le test qui échoue**

Dans `test/controllers/builds_controller_test.rb`, ajouter :

```ruby
  test "public drafts carry a Draft badge" do
    doc = JSON.parse(@document.to_json)
    doc["id"] = "ddddddd9-0000-0000-0000-000000000001"
    Teambuilds::Ingest.call(player: @other, source_uuid: doc["id"], document: doc,
                            visibility: "public", status: "draft")
    draft = Teambuild.find_by(source_uuid: doc["id"])

    get builds_path
    assert_select ".badge", text: "Draft", count: 1

    get build_path(draft)
    assert_select ".badge", text: "Draft", count: 1
  end
```

- [ ] **Step 2: Vérifier l'échec**

Run: `bin/rails test test/controllers/builds_controller_test.rb`
Expected: FAIL — aucun badge « Draft » rendu.

- [ ] **Step 3: Vues**

`app/views/builds/index.html.erb` — après le badge visibilité (ligne 19) :

```erb
          <% if teambuild.status == "draft" %>
            <span class="badge bg-warning text-dark">Draft</span>
          <% end %>
```

`app/views/builds/show.html.erb` — après le badge visibilité (ligne 4) :

```erb
    <% if @teambuild.status == "draft" %>
      <span class="badge bg-warning text-dark">Draft</span>
    <% end %>
```

- [ ] **Step 4: Vérifier le passage**

Run: `bin/rails test test/controllers/builds_controller_test.rb`
Expected: PASS (6 runs)

- [ ] **Step 5: Commit**

```bash
git add app/views/builds/index.html.erb app/views/builds/show.html.erb test/controllers/builds_controller_test.rb
git commit -m "feat(web): badge draft teambuilds in the build library"
```

---

### Task 9: Contrat OpenAPI

**Files:**
- Modify: `docs/openapi/teambuilds.yaml`

Aucun test — documentation. Éditions précises :

- [ ] **Step 1: Route d'export**

Insérer entre le bloc `/api/v1/teambuilds:` (fin ligne 42) et `/api/v1/teambuilds/{id}:` (ligne 43) :

```yaml
  /api/v1/teambuilds/export:
    get:
      summary: Exporter tous les teambuilds visibles en un appel
      description: >
        Résumés enrichis du document .zcx intégral pour tout ce que l'appelant
        peut voir : publics + les siens, drafts publics compris (filtrables via
        status). Réponse unique, sans pagination.
      parameters:
        - { name: status, in: query, schema: { type: string, enum: [draft, published] } }
      responses:
        "200":
          description: Liste complète des teambuilds visibles
          content:
            application/json:
              schema:
                type: object
                properties:
                  teambuilds:
                    type: array
                    items: { $ref: "#/components/schemas/TeambuildExport" }
        "401": { $ref: "#/components/responses/Unauthorized" }
```

- [ ] **Step 2: Paramètre `status` sur PUT et GET liste**

Ligne 71 (PUT), ajouter après le paramètre `visibility` :

```yaml
        - { name: status, in: query, schema: { type: string, enum: [draft, published], default: published }, description: Statut conservé si absent }
```

Ligne 28 (GET liste), ajouter après le paramètre `visibility` :

```yaml
        - { name: status, in: query, schema: { type: string, enum: [draft, published] } }
```

Mettre à jour la description du PUT (ligne 65-68) : « visibility et status en query, défaut private/published ».

- [ ] **Step 3: Schémas**

`ErrorList` (ligne 138) — ajouter `forbidden_tag` à l'enum :

```yaml
              code:
                type: string
                enum: [malformed_json, invalid_source_uuid, not_an_object, wrong_case,
                       null_array, duplicate_attribute_id, invalid_skill_ids,
                       too_many_characters, max_depth, forbidden_tag]
```

`TeambuildSummary` (après `visibility`, ligne 160) :

```yaml
        status: { type: string, enum: [draft, published] }
```

Nouveau schéma après `UpsertResult` (ligne 170) :

```yaml
    TeambuildExport:
      allOf:
        - $ref: "#/components/schemas/TeambuildSummary"
        - type: object
          properties:
            document: { $ref: "#/components/schemas/ZcxDocument" }
```

`ZcxDocument.tags` (ligne 182) — décrire la liste fermée :

```yaml
        tags:
          type: array
          items: { type: string, enum: [GvG, HA, RA, TA, AB, FA, JQ, PvP, PvE] }
          description: Liste fermée imposée à l'ingestion (comparaison insensible à la casse, stockage canonique)
```

Exemple `GvgSplit` (ligne 238) : remplacer `tags: [GvG, meta]` par :

```yaml
        tags: [GvG]
```

- [ ] **Step 4: Valider YAML**

Run: `bin/rails runner "YAML.load_file('docs/openapi/teambuilds.yaml'); puts 'OK'"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add docs/openapi/teambuilds.yaml
git commit -m "docs(openapi): document export, status and forbidden_tag"
```

(Note : `docs/` est gitignoré ; `git add -f` si nécessaire, comme pour les specs précédentes.)

---

### Task 10: Vérification finale

- [ ] **Step 1: Suite complète**

Run: `bin/rails test`
Expected: PASS — 0 failures, 0 errors (tous les fichiers de test).

- [ ] **Step 2: Sanity check manuel des routes**

Run: `bin/rails routes | grep teambuilds`
Expected: voir `export_api_v1_teambuilds GET /api/v1/teambuilds/export` parmi les routes existantes.

- [ ] **Step 3: Cohérence spec ↔ implémentation**

Relire `docs/superpowers/specs/2026-08-23-teambuilds-api-draft-export-design.md` et cocher mentalement : export (Task 7), statut indépendant (Tasks 1/5/6), indexation variants + cap 512 (Tasks 3/4), tags fermés (Tasks 2/4), OpenAPI (Task 9), badge web (Task 8). Tout écart constaté = correctif avant de clore.

---

## Auto-revue du plan (effectuée à la rédaction)

1. **Couverture spec** : §1 export → Task 7 ; §2 statut (migration/scopes/paramètre/filtre/badge) → Tasks 1, 5, 6, 8 ; §3 indexation variants + garde-fou 512 → Tasks 3, 4 ; §4 tags fermés + canonisation → Tasks 2, 4 ; contrat OpenAPI → Task 9 ; tests listés par la spec → présents dans chaque tâche.
2. **Placeholders** : aucun TBD/TODO ; chaque étape de code montre le code complet.
3. **Cohérence des noms** : `STATUSES`, `ALLOWED_TAGS`, `MAX_TOTAL_CHARACTERS`, `with_status`, `draft`/`published`, `export_summary`, paramètres `status` (query) — identiques dans toutes les tâches.
