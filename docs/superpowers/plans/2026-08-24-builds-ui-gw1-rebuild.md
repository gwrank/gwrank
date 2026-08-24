# Refonte UI/UX des pages /builds — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refondre visuellement les pages `/builds` (index + détail) dans un style « fenêtre Guild Wars 1 » sans changer aucune fonctionnalité.

**Architecture:** Nouvelle feuille de style `builds.scss` avec composants préfixés `gw-`, deux nouveaux partials (`_teambuild_row`, `_character_card`), réécriture des deux vues existantes. Une seule adaptation controller : eager-loading des professions pour l'aperçu de l'index (évite un N+1 de ~300 requêtes). Spec : `docs/superpowers/specs/2026-08-24-builds-ui-design.md`.

**Tech Stack:** Rails 8.1, Bootstrap 5.3 (cssbundling-rails, SCSS), Propshaft, Minitest.

**Décisions de conception à connaître:**
- Les badges gardent la classe Bootstrap `badge` en plus des classes `gw-badge-*` (le test existant `"public drafts carry a Draft badge"` cible `.badge`)
- Style élite sur le 8e slot de la barre uniquement s'il est rempli (`skillIds[7]` = élite en zcx)
- Helpers icônes réels : `Profession#html_image_simple(size:)` et `Skill#html_image_simple(size:)` retournent déjà des `<img>` Protshaft-safe (rescue → `''`)

---

### Task 1: Feuille de style des composants GW

**Files:**
- Create: `app/assets/stylesheets/builds.scss`
- Modify: `app/assets/stylesheets/application.bootstrap.scss`

- [ ] **Step 1: Créer `app/assets/stylesheets/builds.scss`**

```scss
// Composants « fenêtre Guild Wars » pour les pages /builds
// Palette alignée sur custom.scss

.gw-window {
  background: rgba(10, 7, 3, 0.92);
  border: 2px solid #9c7c3c;
  border-radius: 6px;
  box-shadow: inset 0 0 24px rgba(0, 0, 0, 0.85);
  overflow: hidden;
}

.gw-window-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: linear-gradient(#3a2c14, #241a09);
  border-bottom: 1px solid #9c7c3c;
}

.gw-title {
  color: #f4dfa0;
  font-size: 1.15rem;
  margin: 0;
  letter-spacing: 0.5px;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.9);
}

.gw-count {
  color: #9b8a5f;
  font-size: 0.75rem;
  margin-left: 8px;
}

.gw-search {
  display: flex;
  gap: 6px;
  margin-left: auto;
}

.gw-search-input {
  background: #100b05;
  border: 1px solid #7a5f28;
  color: #ffe9ad;
  border-radius: 3px;
  padding: 4px 10px;
  min-width: 200px;

  &::placeholder { color: #9b8a5f; }
  &:focus {
    outline: none;
    border-color: #c9a959;
    box-shadow: 0 0 6px rgba(201, 169, 89, 0.4);
  }
}

.gw-btn {
  display: inline-block;
  background: linear-gradient(#c9a959, #9c7c3c);
  color: #171006 !important;
  border: 1px solid #f4dfa0;
  border-radius: 3px;
  padding: 4px 12px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;

  &:hover {
    background: linear-gradient(#dcbb6b, #a8853f);
    color: #000 !important;
    text-decoration: none;
  }
}

.gw-list {
  display: block;
}

.gw-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-bottom: 1px solid #241a09;
  border-left: 3px solid transparent;
  transition: background 0.15s ease, border-color 0.15s ease;

  &:hover {
    background: #171006;
    border-left-color: #cd9219;
  }
}

.gw-row-profs {
  display: grid;
  grid-template-columns: repeat(3, auto);
  gap: 3px;
  flex-shrink: 0;
}

.gw-prof-icon img {
  border-radius: 50%;
  border: 1px solid #9c7c3c;
  background: #241a09;
}

.gw-prof-more {
  color: #6b5c38;
  font-size: 0.7rem;
  align-self: center;
}

.gw-row-main {
  flex: 1;
  min-width: 0;
}

.gw-row-name {
  display: block;
  color: #ffe9ad;
  font-weight: bold;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.gw-row-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
}

.gw-row-meta {
  color: #9b8a5f;
  font-size: 0.75rem;
  text-align: right;
  white-space: nowrap;
  flex-shrink: 0;
}

.gw-badge-mode {
  background: linear-gradient(#c9a959, #9c7c3c);
  color: #171006;
  font-weight: 600;
}

.gw-badge-tag {
  background: transparent;
  color: #e8d9a8;
  border: 1px solid #7a5f28;
}

.gw-badge-draft {
  background: #5c4a14;
  color: #ffd98a;
  border: 1px solid #cd9219;
}

.gw-badge-visibility {
  background: #2b1815;
  color: #b9a08a;
  border: 1px solid #4b2a22;
}

.gw-empty {
  color: #9b8a5f;
  text-align: center;
  padding: 32px 16px;
  margin: 0;
}

.gw-build-header .gw-header-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.gw-character-card + .gw-character-card {
  margin-top: 12px;
}

.gw-character-name {
  color: #ffe9ad;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.gw-dominant {
  margin-left: auto;
  color: #9b8a5f;
}

.gw-character-body {
  padding: 12px 14px;
}

.gw-skillbar {
  display: flex;
  gap: 3px;
  flex-wrap: wrap;
  margin-bottom: 10px;
}

.gw-skillbar-slot {
  width: 31px;
  height: 31px;
  background: #241a09;
  border: 2px solid #9c7c3c;
  border-radius: 4px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.gw-skillbar-slot--empty {
  opacity: 0.55;
}

.gw-skillbar-slot--elite {
  border-color: #f4dfa0;
  box-shadow: 0 0 8px rgba(244, 223, 160, 0.5);
}

.gw-attributes {
  list-style: none;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 4px 18px;
  padding: 0;
  margin: 0 0 8px;
  color: #cfcfcf;
  font-size: 0.85rem;

  li { display: flex; justify-content: space-between; }

  .gw-attribute-points {
    color: #ffe9ad;
    font-weight: bold;
  }
}

.gw-notes {
  color: #8a7565;
  font-style: italic;
  font-size: 0.85rem;
  margin: 0;
}

@media (max-width: 575.98px) {
  .gw-row {
    flex-wrap: wrap;

    .gw-row-meta {
      width: 100%;
      order: 3;
      text-align: left;
    }
  }

  .gw-attributes {
    grid-template-columns: 1fr;
  }
}
```

- [ ] **Step 2: Importer la feuille dans `app/assets/stylesheets/application.bootstrap.scss`**

Le fichier doit contenir exactement :

```scss
@import 'bootstrap/scss/bootstrap';
@import 'bootstrap-icons/font/bootstrap-icons';

@import 'monsterplay';
@import 'custom';
@import 'builds';
```

- [ ] **Step 3: Vérifier que la compilation SCSS passe**

Run: `bin/rails assets:precompile`
Expected: sortie sans erreur (le fichier `application.css` est régénéré)

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/builds.scss app/assets/stylesheets/application.bootstrap.scss
git commit -m "feat(web): add GW-styled window components stylesheet"
```

---

### Task 2: Index des builds — liste enrichie

**Files:**
- Create: `app/views/builds/_teambuild_row.html.erb`
- Modify: `app/views/builds/index.html.erb`
- Modify: `app/controllers/builds_controller.rb:7` (eager-loading)
- Test: `test/controllers/builds_controller_test.rb`

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à la fin de `test/controllers/builds_controller_test.rb` :

```ruby
  test "index renders the GW window structure" do
    sign_in @owner
    get builds_path
    assert_response :success
    assert_select ".gw-window", count: 1
    assert_select ".gw-row", count: 1
    assert_select ".gw-badge-mode", text: "PvP"
    assert_select ".gw-badge-tag", text: "GvG"
  end

  test "index shows an empty state when nothing matches" do
    sign_in @owner
    get builds_path, params: { q: "inexistant" }
    assert_response :success
    assert_select ".gw-empty"
  end
```

- [ ] **Step 2: Vérifier que les tests échouent**

Run: `bin/rails test test/controllers/builds_controller_test.rb`
Expected: 2 FAIL (`Expected exactly 1 element matching ".gw-window"`)

- [ ] **Step 3: Adapter l'eager-loading du controller**

Dans `app/controllers/builds_controller.rb`, remplacer :

```ruby
    @teambuilds = scope.order(updated_at: :desc).includes(:teambuild_characters).limit(50)
```

par :

```ruby
    @teambuilds = scope.order(updated_at: :desc).includes(teambuild_characters: :primary_profession).limit(50)
```

- [ ] **Step 4: Créer le partial `app/views/builds/_teambuild_row.html.erb`**

```erb
<a class="gw-row" href="<%= build_path(teambuild) %>">
  <span class="gw-row-profs" aria-hidden="true">
    <% teambuild.teambuild_characters.first(6).each do |character| %>
      <span class="gw-prof-icon"><%= character.primary_profession&.html_image_simple(size: 24) %></span>
    <% end %>
    <% if teambuild.teambuild_characters.size > 6 %>
      <span class="gw-prof-more">+<%= teambuild.teambuild_characters.size - 6 %></span>
    <% end %>
  </span>
  <span class="gw-row-main">
    <span class="gw-row-name"><%= teambuild.name.presence || "(sans nom)" %></span>
    <span class="gw-row-badges">
      <% if teambuild.status == "draft" %>
        <span class="badge gw-badge-draft">Draft</span>
      <% end %>
      <% if teambuild.visibility != "public" %>
        <span class="badge gw-badge-visibility"><%= teambuild.visibility %></span>
      <% end %>
      <span class="badge gw-badge-mode"><%= teambuild.game_mode.presence || "?" %></span>
      <% teambuild.tags.each do |tag| %>
        <span class="badge gw-badge-tag"><%= tag %></span>
      <% end %>
    </span>
  </span>
  <span class="gw-row-meta"><%= teambuild.player_count %> persos · maj <%= teambuild.updated_at.strftime("%d/%m/%Y") %></span>
</a>
```

- [ ] **Step 5: Réécrire `app/views/builds/index.html.erb`**

Remplacer tout le contenu par :

```erb
<div class="container mt-4">
  <div class="gw-window">
    <div class="gw-window-header">
      <h1 class="gw-title">Bibliothèque de builds <span class="gw-count"><%= @teambuilds.size %> builds</span></h1>
      <%= form_with url: builds_path, method: :get, local: true, class: "gw-search" do %>
        <%= text_field_tag :q, params[:q], class: "gw-search-input", placeholder: "Nom du teambuild…" %>
        <button class="gw-btn" type="submit">Rechercher</button>
      <% end %>
    </div>
    <div class="gw-list">
      <% if @teambuilds.any? %>
        <%= render partial: "teambuild_row", collection: @teambuilds, as: :teambuild %>
      <% else %>
        <p class="gw-empty">
          Aucun build trouvé.<% if params[:q].present? %> Aucun résultat pour « <%= params[:q] %> ».<% end %>
        </p>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 6: Vérifier que tous les tests du fichier passent**

Run: `bin/rails test test/controllers/builds_controller_test.rb`
Expected: 8 runs, 0 failures (les 6 tests existants restent verts — les assertions texte ne changent pas, et `.badge` est conservé sur les badges Draft)

- [ ] **Step 7: Commit**

```bash
git add app/views/builds/index.html.erb app/views/builds/_teambuild_row.html.erb app/controllers/builds_controller.rb test/controllers/builds_controller_test.rb
git commit -m "feat(web): rebuild the build library index with GW windows"
```

---

### Task 3: Page détail — cartes personnages avec barre de skills

**Files:**
- Create: `app/views/builds/_character_card.html.erb`
- Modify: `app/views/builds/show.html.erb`
- Test: `test/controllers/builds_controller_test.rb`

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter à la fin de `test/controllers/builds_controller_test.rb` :

```ruby
  test "show renders character cards with skill bars" do
    sign_in @owner
    get build_path(Teambuild.last)
    assert_response :success
    assert_select ".gw-character-card", minimum: 1
    assert_select ".gw-skillbar-slot", minimum: 8
    assert_select ".gw-skillbar-slot--elite", minimum: 1
    assert_select ".gw-attribute-points", minimum: 1
  end
```

- [ ] **Step 2: Vérifier que le test échoue**

Run: `bin/rails test test/controllers/builds_controller_test.rb`
Expected: 1 FAIL (`Expected at least 1 element matching ".gw-character-card"`)

- [ ] **Step 3: Créer le partial `app/views/builds/_character_card.html.erb`**

```erb
<div class="gw-window gw-character-card">
  <div class="gw-window-header">
    <span class="gw-row-profs" aria-hidden="true">
      <span class="gw-prof-icon"><%= row[:summary].primary_profession&.html_image_simple(size: 26) %></span>
      <span class="gw-prof-icon"><%= row[:summary].secondary_profession&.html_image_simple(size: 26) %></span>
    </span>
    <strong class="gw-character-name"><%= row[:summary].name.presence || "(sans nom)" %></strong>
    <% if row[:summary].assignment.present? %>
      <span class="badge gw-badge-mode"><%= row[:summary].assignment %></span>
    <% end %>
    <% if row[:summary].dominant_attribute.present? %>
      <small class="gw-dominant"><%= row[:summary].dominant_attribute %></small>
    <% end %>
  </div>
  <div class="gw-character-body">
    <div class="gw-skillbar">
      <% row[:skills].each_with_index do |skill, index| %>
        <% if skill %>
          <span class="gw-skillbar-slot <%= "gw-skillbar-slot--elite" if index == 7 %>" title="<%= skill.name %>"><%= skill.html_image_simple(size: 30) %></span>
        <% else %>
          <span class="gw-skillbar-slot gw-skillbar-slot--empty"></span>
        <% end %>
      <% end %>
    </div>
    <% if row[:attributes].any? %>
      <ul class="gw-attributes">
        <% row[:attributes].each do |attribute| %>
          <li><span class="gw-attribute-name"><%= attribute[:name] %></span> <span class="gw-attribute-points"><%= attribute[:points] %></span></li>
        <% end %>
      </ul>
    <% end %>
    <% if row[:notes].present? %>
      <p class="gw-notes"><%= row[:notes] %></p>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Réécrire `app/views/builds/show.html.erb`**

Remplacer tout le contenu par :

```erb
<div class="container mt-4">
  <div class="gw-window mb-3">
    <div class="gw-window-header">
      <h1 class="gw-title"><%= @teambuild.name.presence || "(sans nom)" %></h1>
      <span class="gw-header-badges">
        <% if @teambuild.visibility != "public" %>
          <span class="badge gw-badge-visibility"><%= @teambuild.visibility %></span>
        <% end %>
        <% if @teambuild.status == "draft" %>
          <span class="badge gw-badge-draft">Draft</span>
        <% end %>
        <span class="badge gw-badge-mode"><%= @teambuild.game_mode.presence || "?" %></span>
        <% @teambuild.tags.each do |tag| %>
          <span class="badge gw-badge-tag"><%= tag %></span>
        <% end %>
      </span>
      <%= link_to "Télécharger .zcx", download_build_path(@teambuild), class: "gw-btn ms-auto" %>
    </div>
  </div>

  <% if @rows.any? %>
    <%= render partial: "character_card", collection: @rows, as: :row %>
  <% else %>
    <div class="gw-window"><p class="gw-empty">Ce build ne contient aucun personnage.</p></div>
  <% end %>
</div>
```

- [ ] **Step 5: Vérifier que tous les tests du fichier passent**

Run: `bin/rails test test/controllers/builds_controller_test.rb`
Expected: 9 runs, 0 failures

- [ ] **Step 6: Commit**

```bash
git add app/views/builds/show.html.erb app/views/builds/_character_card.html.erb test/controllers/builds_controller_test.rb
git commit -m "feat(web): rebuild the build detail page with GW character cards"
```

---

### Task 4: Vérification finale

- [ ] **Step 1: Lancer toute la suite de tests**

Run: `bin/rails test`
Expected: 0 failures, 0 errors

- [ ] **Step 2: Vérification visuelle manuelle**

Lancer `bin/rails s` puis vérifier dans le navigateur (desktop **et** largeur 375px via devtools) :
- `/builds` : fenêtre unique, recherche fonctionnelle, hover doré sur les rangées, aperçu professions visible
- Recherche sans résultat : message d'état vide
- `/builds/:id` : header avec badges + bouton télécharger, une carte par perso, barre 8 slots avec slot 8 doré, attributs sur 2 colonnes (desktop) / 1 colonne (mobile), notes en italique

- [ ] **Step 3: Nettoyer les artefacts de précompilation éventuels**

```bash
git status --short
```

Expected: uniquement des fichiers volontairement modifiés ; ne rien committer d'autre.
