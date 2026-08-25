# Design — Nouvelle page d'accueil vitrine + menu « Bot & Docs »

Date : 2026-08-25
Statut : Validé en brainstorming (structure et contenu choisis via compagnon visuel, maquette haute-fidélité approuvée)

## Contexte

La page d'accueil actuelle (« Hall of Heroes », `app/views/home/index.html.erb`) ne présente que le bot Discord. Or GWRank.com offre aujourd'hui quatre piliers :

1. une bibliothèque de builds/teambuilds compatible Z-Codex (`.zcx`, API REST),
2. un bot Discord (partage de builds, organisation AT/mAT de guilde),
3. l'organisation de scrims ouverts,
4. une archive historique de tournois et matchs (rôle d'archive maintenant que gvg.report et Tolkano existent).

Décisions validées :

- **Objectif** : vitrine pure — présenter l'offre aux nouveaux joueurs/guildes, sans données dynamiques
- **Langue** : anglais (cohérent avec le reste du site, chaînes codées en dur, pas d'I18n)
- **Structure** : hero compact + grille bento, carte vedette = bibliothèque de builds
- **Menu principal** : `Builds` · `Bot & Docs` · `Archives` — les scrims ne figurent pas dans le menu (accès depuis la carte de la home uniquement)
- **Page dédiée au bot** : le contenu actuel de la home déménage vers `/bot` (`DocumentationController#bot`)
- **Invite Discord** : unification sur celle déjà utilisée par le footer (`https://discord.gg/jqShPZBkcj`) — l'invite `Gjefv7GJ9g` de l'actuelle home disparaît
- **Sous-titre de marque** : « Guild Wars · Hall of Heroes » devient « Guild Wars · GvG Tools » (l'ancien nom désignait l'actuelle home)

## Périmètre

| Élément | Action |
|---|---|
| `app/views/home/index.html.erb` | Réécriture complète (vitrine bento) |
| `app/controllers/home_controller.rb` | Suppression des instance vars inutilisées (`@queue_count`, `@recent_scrims`, `@scrims_count`) |
| `config/routes.rb` | Ajout `get '/bot', to: 'documentation#bot', as: :bot` (à côté des routes de doc) |
| `app/controllers/documentation_controller.rb` | Nouvelle action `bot` |
| `app/views/documentation/bot.html.erb` | Nouvelle vue (reprend le contenu actuel de la home) |
| `app/views/documentation/_sidebar.html.erb` | Ajout d'une entrée « Discord Bot » → `/bot` |
| `app/helpers/gw_layout_helper.rb` | `main_nav_items` → Builds / Bot & Docs / Archives |
| `app/views/application/_gw_topbar.html.erb` | Sous-titre de marque |
| `test/controllers/home_controller_test.rb` | Réécriture (tests actuels déjà rouges : assertent l'ancienne home avec stats scrims/queue) |
| Tests `/bot` | Nouveau test d'intégration |

Controllers/models/routes existants : aucun autre changement. Aucun nouveau modèle.

## Navigation & routage

- `main_nav_items` :
  ```ruby
  [
    { label: "Builds", path: builds_path },
    { label: "Bot & Docs", path: bot_path },
    { label: "Archives", path: tournaments_path }
  ]
  ```
- L'état actif (`gw_nav_active?`) surlignera « Bot & Docs » sur `/bot` et les pages de doc via préfixe de path.
- Recherche 🔍, connexion Discord OAuth et zone profil de la topbar : inchangés.

## Page d'accueil (`home#index`)

Contenu statique, styles du design system GW existant (`gw-window`, palette or/encre, Cinzel/EB Garamond). Copie exacte :

### Hero (compact, centré)

- Titre (font-display, or) : **GWRANK**
- Tagline (italique) : *« Builds, teambuilds and a Discord bot — everything your guild needs to prepare its GvG matches. »*
- CTAs :
  - `Add Bot to Discord` → `https://discord.com/oauth2/authorize?client_id=788778440877801504` (externe, `target="_blank"`)
  - `Browse Builds` (ghost) → `builds_path`

### Grille bento (5 cartes, ordre DOM = ordre mobile)

1. **Build & Teambuild Library** — carte vedette, occupe 2 colonnes × 2 lignes
   - Sur-titre discret : « Z-Codex Compatible » — icône 📜
   - Texte : *« Browse community builds and full teambuilds stored in the open Z-Codex (.zcx) format — professions, attributes, elite skills and player assignments included. Download any teambuild and open it straight into Z-Codex to iterate on your composition. »*
   - Second paragraphe : *« Every build is versioned, tagged by game mode and strategy, and exposed through a REST API so your own tools can consume it. »*
   - Liens : « Browse the library → » → `builds_path` ; « API documentation » → `/api-docs`
2. **Discord Bot** — icône 🤖
   - Texte : *« Share builds and teambuilds in your server with /build and /teambuild. Organize your guild's daily AT and monthly mAT registrations without leaving Discord. »*
   - Lien : « Bot & Docs → » → `bot_path`
3. **Open Scrims** — icône ⚔️
   - Texte : *« Queue up solo or as a guild, get teams formed and play structured GvG scrimmages with score tracking. »*
   - Lien : « Join the queue → » → `scrims_path`
4. **Tournament Archives** — icône 🏆
   - Texte : *« Years of Automated Tournament history — brackets, matches, rosters and ratings preserved and searchable. »*
   - Lien : « Explore the archives → » → `tournaments_path`
5. **Documentation** — icône 📖
   - Mini-liste : `/build` — share single builds · `/teambuild` — pawned2 teambuilds · `/at` · `/mat` — tournaments · `/scrim` — scrim commands
   - Lien : « All commands → » → `bot_path`

Placement desktop (≥ lg, 3 colonnes) :

```
┌──────────────┬──────────────┬───────────┐
│ Build Library│ Build Library│ Discord   │
│ (vedette     │ (vedette     │ Bot       │
│  2×2)        │  2×2)        ├───────────┤
│              │              │ Open      │
│              │              │ Scrims    │
├──────────────┴──────────────┼───────────┤
│ Tournament Archives         │ Documenta-│
│                             │ tion      │
└─────────────────────────────┴───────────┘
```

## Page `/bot` (`documentation#bot`)

Reprise quasi verbatim de l'actuelle `home/index.html.erb`, habillée comme les pages de doc sœurs :

- Structure commune : `_breadcrumb` (« Bot & Docs ») + `_sidebar` + conteneur `gw-doc`
- Hero : titre « GWRank Discord Bot », texte actuel (*« Share builds, teambuilds and organize automated tournaments… »*), CTAs « Add Bot to Discord » et « Join our Discord » → `https://discord.gg/jqShPZBkcj`
- Les 4 cartes de documentation (Build Commands, Team Build Commands, Automated Tournament, Monthly AT) : inchangées, liens vers les routes doc existantes
- Section « How to Use the Bot » : conservée telle quelle
- **Supprimé** : le bloc login/logout redondant (la topbar gère déjà l'état connecté)

## Responsive

- Mobile (< sm) : 1 colonne — vedette, Bot, Scrims, Archives, Documentation (ordre DOM ci-dessus)
- Tablette (sm → lg) : 2 colonnes — vedette pleine largeur, puis paires Bot/Scrims et Archives/Documentation
- Desktop (≥ lg) : disposition 3×3 décrite plus haut
- Hero : padding réduit, tagline max-width ~520px centrée

## Erreurs / états limites

- Contenu statique : aucune requête DB, aucun état d'échec propre à la page
- Utilisateur connecté/non connecté : seule la topbar varie (comportement existant)
- Liens externes Discord : `target="_blank"` + `rel="noopener noreferrer"`
- Anciens bookmarks : aucun impact — `root` inchangé, toutes les routes doc conservées

## Tests

- `test/controllers/home_controller_test.rb` : réécriture intégrale
  - `GET /` → 200, présence du titre GWRANK, de la tagline, des 5 cartes et des deux CTAs du hero
  - Absence de régression : les anciens tests (déjà rouges) sont remplacés, pas conservés
- Nouveau test (fichier `test/controllers/documentation_controller_test.rb` s'il n'existe pas encore) :
  - `GET /bot` → 200, présence du lien « Add Bot to Discord », des 4 cartes de doc et de l'invite Discord unifiée
- Suite complète relancée pour vérifier l'absence de régression (notamment vues référençant `main_nav_items`)

## Hors périmètre

- Internationalisation (I18n), sélecteur de langue
- Données dynamiques sur la home (scrims récents, file d'attente…)
- Refonte des pages Builds/Archives/Scrims elles-mêmes
- Branding, logo, favicon
- Contenu éditorial nouveau (textes des pages doc existantes)
