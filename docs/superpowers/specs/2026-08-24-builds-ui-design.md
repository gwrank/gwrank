# Design — Refonte UI/UX des pages /builds

Date : 2026-08-24
Statut : Validé en brainstorming (direction visuelle + mises en page choisies via compagnon visuel)

## Contexte

Les pages `/builds` (bibliothèque de teambuilds) sont fonctionnellement complètes mais visuellement basiques : une `list-group` Bootstrap brute pour l'index, des cartes Bootstrap génériques pour le détail. Le site utilise un thème sombre « Guild Wars » (palette brun/or définie dans `custom.scss`).

Décisions validées :

- **Objectif** : refonte visuelle complète, sans nouvelle fonctionnalité
- **Direction** : style « fenêtre Guild Wars 1 » fidèle — panneaux sombres translucides, bordures bronze double liseré, titres dorés en dégradé
- **Index** : liste enrichie avec aperçu des professions par ligne
- **Détail** : cartes empilées, une par personnage, avec barre de 8 skills façon jeu
- **Appareils** : mobile et desktop à parts égales

## Périmètre

| Élément | Action |
|---|---|
| `app/views/builds/index.html.erb` | Refonte |
| `app/views/builds/show.html.erb` | Refonte |
| `app/views/builds/_teambuild_row.html.erb` | Nouveau partial |
| `app/views/builds/_character_card.html.erb` | Nouveau partial |
| `app/assets/stylesheets/builds.scss` | Nouveau fichier, importé dans `application.bootstrap.scss` après `custom.scss` |
| Controllers / modèles / routes | Aucun changement |

## Composants CSS partagés (`builds.scss`)

Toutes les classes préfixées `gw-` pour éviter les collisions Bootstrap :

- `.gw-window` : panneau translucide (`rgba(10,7,3,.92)`), bordure 2px `#9c7c3c`, rayon 6px, ombre interne sombre
- `.gw-window-header` : dégradé linéaire `#3a2c14 → #241a09`, texte doré `#f4dfa0`, liseré bas bronze, légère letter-spacing
- `.gw-badge-mode` : dégradé or (`#c9a959 → #9c7c3c`), texte sombre — pour le mode de jeu
- `.gw-badge-tag` : contour fin `#7a5f28`, texte `#e8d9a8`, fond transparent — pour les tags
- `.gw-badge-draft` / `.gw-badge-visibility` : variantes distinctes (draft = ambre discret ; private = gris-brun)
- `.gw-skillbar` : flex de 8 cases carrées ~30px, fond `#241a09`, bordure bronze ; `.gw-skillbar-slot--elite` : bordure dorée `#f4dfa0` + halo lumineux (toujours le slot 8)
- `.gw-prof-icon` : icône de profession ronde avec anneau bronze (tailles 22–28px selon contexte)
- `.gw-btn` : bouton façon GW (dégradé bronze, texte sombre) pour « Télécharger .zcx » et la recherche
- `.gw-search-input` : champ sombre à liseré bronze

Réutilise les helpers existants : `Profession#html_image_simple(size:)` et `Skill#html_image_simple(size:)` (vraies icônes du jeu).

## Page index (`/builds`)

Structure :

1. Une `.gw-window` englobante
2. Header de fenêtre : titre « Bibliothèque de builds » + compteur sur les résultats affichés (`@teambuilds.size`, plafonné à 50 par le controller) + formulaire de recherche intégré (champ + bouton stylés)
3. Rangées (partial `_teambuild_row`) :
   - Colonne gauche : aperçu professions = jusqu'à 6 icônes rondes (primaire de chaque personnage) + indicateur « +N » si plus
   - Centre : nom du build (défaut : « (sans nom) »), badges dessous — mode, tags, Draft, visibilité privée
   - Droite : meta « X persos · maj JJ/MM/AAAA »
4. Hover : liseré doré + fond légèrement éclairci, transition courte
5. État vide (aucun build ou recherche sans résultat) : message centré dans la fenêtre (« Aucun build trouvé », avec mention de la recherche active le cas échéant)

Données utilisées (déjà exposées) : `name`, `visibility`, `status`, `game_mode`, `tags`, `player_count`, `updated_at`, `teambuild_characters` (pour les professions).

## Page détail (`/builds/:id`)

1. Fenêtre d'en-tête : nom du build, badges (visibilité, Draft, mode, tags), bouton « Télécharger .zcx » à droite (`.gw-btn`)
2. Une carte `.gw-window` par personnage (partial `_character_card`), construite depuis `@rows` existant :
   - Header : icônes prof primaire + secondaire, nom du perso (défaut : « (sans nom) »), badge assignment, attribut dominant aligné à droite
   - Body : barre des 8 skills (icônes réelles, cases vides si slot manquant), grille d'attributs (2 colonnes desktop / 1 mobile, « Nom **points** »), notes en italique gris discret si présentes

Le style élite s'applique au 8e slot uniquement s'il est rempli ; si la barre compte moins de 8 skills, aucune case dorée (convention zcx : `skillIds[7]` = élite).

## Responsive

- Barre de skills : 8 × ~31px ≈ 250px → tient sur écran 360px
- Rangées index : passage en pile verticale sous `sm` (aperçu professions au-dessus du nom, meta sous les badges)
- Grille d'attributs : 1 colonne mobile, 2 colonnes ≥ 768px

## Erreurs / états limites

- Build introuvable ou privé : comportement actuel conservé (redirection + alert)
- Skills manquants : case vide stylée (pas de crash — `Array(...)` déjà défensif côté controller)
- Personnage sans profession : icônes omises proprement (`&.` déjà en place)
- Aucun build : état vide décrit ci-dessus

## Tests

- Les tests minitest existants (request/view sur builds) doivent rester verts
- Mise à jour des assertions `assert_select` si elles ciblent les classes Bootstrap supprimées
- Ajout d'assertions légères sur la structure nouvelle (`.gw-window`, présence des icônes de profession dans l'index) si un test view existe déjà ; pas de création de suite exhaustive pour du pur CSS

## Hors périmètre

Filtres avancés, tri, pagination, édition en ligne, changement de thème global du site.
