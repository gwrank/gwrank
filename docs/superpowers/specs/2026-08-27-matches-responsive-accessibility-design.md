# Design — Améliorer le responsive et l'accessibilité de /matches

Date : 2026-08-27
Statut : Validé (brainstorming)

## Problème

La page `/matches` présente des problèmes de responsive et d'accessibilité :

1. **Ligne de match tronquée sur mobile** : noms de guildes coupés par `truncate` sur une seule ligne ; les chips de professions (~16 × 24px) débordent hors de l'écran.
2. **Popup builds au survol uniquement** : invisible au tactile, inaccessible au clavier, pas d'état `aria-expanded`, pas de fermeture par Échap.
3. **Script inline `DOMContentLoaded`** pour le champ « AT Region » : ne se ré-exécute pas après navigation Turbo → champ restant grisé/bloqué.
4. **`<button>` imbriqué dans un `<a>`** (structure actuelle du markup) : HTML invalide, impossible de focuser le déclencheur du popup.
5. **🏆 annoncé seulement via `title=""`** : non fiable pour les lecteurs d'écran.
6. **Pagination sans `<nav aria-label>`** : contexte manquant pour les lecteurs d'écran.

## Périmètre validé

Groupes A + B + C + D (tous). Approche retenue : partiels existants + contrôleurs Stimulus (convention du projet, pas de ViewComponent).

## Section 1 — Ligne de match & popup builds

### Structure HTML (`_match.html.erb`)

- Le `<li>` devient un conteneur : le lien principal (`gw-row`, conserve la navigation vers la page match) ne contient **que le texte**.
- Les chips de professions deviennent un vrai `<button type="button">` à **côté** du lien (plus de bouton imbriqué dans un lien).
- **Mobile (< `sm`)** : disposition empilée —
  - équipe 1 : `#rang` + nom + 🏆, puis chips équipe 1 en dessous ;
  - séparateur « VS » décoratif (`aria-hidden`) ;
  - équipe 2 identique ;
  - ligne méta (round · type · date) en bas.
- **Desktop (≥ `sm`)** : forme actuelle une-ligne avec chips à droite, conservée à l'identique.
- **🏆** : emoji visuel conservé, doublé d'un `<span class="sr-only">Winner</span>` (le `title` seul n'est pas annoncé de manière fiable).
- Bouton chips : `aria-label="Show builds"`, `aria-expanded` (état), `aria-controls` → id unique `match-builds-popup-<id>`.
- Popup : overlay comme aujourd'hui, id unique par match, `max-height` ~70vh + `overflow-y-auto` (16 joueurs débordent sur mobile).

### Stimulus (`match_builds_controller.js` étendu)

- Survol souris : conservé (mouseenter/mouseleave).
- Tap/clic sur le bouton : toggle ouvert/fermé.
- Focus clavier (Tab) : ouvre ; blur : ferme.
- **Échap** : ferme et rend le focus au bouton.
- Clic ailleurs sur la page : ferme.
- `aria-expanded` synchronisé à chaque changement d'état.

## Section 2 — Filtres

### Nouveau contrôleur `filters_controller.js`

- Remplace le `<script>` inline (`DOMContentLoaded`) actuel.
- Stimulus se connecte automatiquement après navigation Turbo → le champ « AT Region » s'active/se désactive correctement à chaque navigation.
- Le contrôleur surveille le champ `tournament_type` : si `at`, le champ région s'active ; sinon désactivé et valeur effacée.
- Comportement identique à aujourd'hui, plus robuste.

### Aides aux formulaires

- Champ « AT Region » désactivé : libellé visible + hint statique `<p class="text-xs text-muted">Only for AT</p>`.
- Labels existants corrects : aucun changement.
- Bouton « Filter » explicite conservé (pas d'auto-submit).
- `<details>` des filtres : HTML natif accessible, conservé avec son indicateur « active/none ».

## Section 3 — Sémantique & lecteurs d'écran

- **Pagination** : wrapper en `<nav aria-label="Pagination">` ; markup stand-alone Pagy (option pour générer des `<a>` sans `<ul>`) en conservant les sélecteurs CSS `gw-pagy`. S'assurer d'un `aria-current="page"` sur la page courante.
- `aria-hidden` sur les images de professions à l'intérieur du bouton chips (décoratives ; le bouton porte son `aria-label`).
- Vérifications en fin d'implémentation : hiérarchie de titres (`h1` existant, pas de saut), contraste (`--color-muted` ≈ 5.9:1 → AA OK). Optionnel : `--color-faded` (#7d6d48 ≈ 3.9:1, uniquement placeholders) vers ~#8a7a54 pour tout passer AA.

## Tests & vérification

- Adapter `matches_controller_test.rb` si les sélecteurs changent (ex. `li[data-controller="match-builds"]` conserve son emplacement).
- Vérifier le comportement du contrôleur `filters` (activation/désactivation région + effacement de valeur) via le setup de test existant.
- Vérifications manuelles :
  - responsive 375 / 768 / desktop ;
  - clavier : Tab → bouton chips, Échap → fermeture + retour de focus ;
  - navigation Turbo entre pages (filtre région reste fonctionnel).