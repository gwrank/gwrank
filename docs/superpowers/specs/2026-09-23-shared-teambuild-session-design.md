# Canal de session partagée pour la co-édition de teambuilds

**Date :** 2026-09-23
**Statut :** design validé en conversation, implémentation non commencée
**Périmètre :** backend Rails GWRank et contrat consommé par Z-Codex

## Objectif

Permettre à 2 à 8 utilisateurs de travailler simultanément sur un même teambuild pendant une
session éphémère. Chaque participant choisit son personnage côté client ; les paquets d'état sont
transportés par GWRank, qui ne connaît pas le format `.zcx` et ne résout aucun conflit métier.

Le serveur conserve le dernier paquet accepté par salon afin qu'un nouvel arrivant puisse reprendre
la session immédiatement. Aucun teambuild, historique ou contenu de chat ne sera persisté comme
donnée applicative.

## Décisions validées

- `POST /api/v1/rooms` exige le `Bearer` API token GWRank existant.
- La connexion WebSocket ne demande pas de compte ; le code du salon est le moyen d'accès des participants.
- La création renvoie un `creatorSecret` séparé du code partageable.
- Le secret créateur est transmis dans les paramètres de souscription et n'est jamais stocké en clair.
- L'état partagé utilise le cache Rails avec Solid Cache en production.
- Les opérations concurrentes sont sérialisées par verrous advisory PostgreSQL.
- Un salon accepte au maximum 8 connexions et 100 salons sont acceptés simultanément.
- Une charge décodée est limitée à 16 KiB.
- Un salon accepte au maximum 10 messages par seconde.
- La durée de vie absolue d'un salon est de 2 heures.
- La perte du créateur déclenche une grace de reconnexion de 5 minutes.
- Une reconnexion reçoit un nouvel identifiant opaque et le dernier état.
- Le keepalive de présence applicatif est de 30 secondes ; une connexion absente depuis 90 secondes est considérée comme morte.
- Les codes de fermeture applicatifs sont documentés et stables.
- Solid Cable reste le transport inter-processus Action Cable existant.

## Architecture

### API de création

La route `POST /api/v1/rooms` sera ajoutée sous le namespace API v1. Le contrôleur réutilisera
le mécanisme `authenticate_or_request_with_http_token` déjà présent dans les contrôleurs API.

La création sera effectuée par `Rooms::SessionStore` sous un verrou global d'index :

1. Nettoyer de l'index les codes dont le snapshot est absent ou expiré.
2. Refuser la création si 100 salons actifs sont déjà recensés.
3. Générer un code cryptographiquement aléatoire au format `XXXX-XXX`, en majuscules, avec un alphabet excluant les caractères ambigus.
4. Générer un secret créateur aléatoire de forte entropie.
5. Stocker uniquement le digest du secret dans le snapshot.
6. Écrire le snapshot et l'entrée d'index avec une échéance absolue de deux heures.

La réponse sera `201 Created` :

```json
{
  "code": "KURZ-7T4",
  "creatorSecret": "base64url-sans-padding",
  "websocketUrl": "wss://gwrank.com/cable",
  "expiresAt": "2026-09-23T18:00:00Z",
  "limits": {
    "participants": 8,
    "payloadBytes": 16384,
    "messagesPerSecond": 10
  }
}
```

Un dépassement de la capacité globale renverra `503 Service Unavailable` avec l'erreur
`rooms_full`. Il n'existera ni endpoint de lecture, ni endpoint de suppression, ni endpoint de
lecture d'historique.

### Connexion Action Cable

Action Cable sera monté sur `/cable`. L'URL est renvoyée par la création afin que le client ne
dépende pas d'un chemin codé en dur. Le code de salon n'est pas placé dans l'URL ; il est envoyé
dans l'identifiant de souscription :

```json
{
  "channel": "RoomChannel",
  "code": "KURZ-7T4",
  "creatorSecret": "base64url-sans-padding"
}
```

Le champ `creatorSecret` est absent pour un participant normal. Le secret n'est donc pas exposé
dans l'URL WebSocket ou dans un lien partageable. Le code reste un secret bearer lisible à voix
haute ; sa génération aléatoire et la limitation des opérations réduisent les tentatives
d'énumération.

`ApplicationCable::Connection` attribuera un `connectionId` UUID opaque à chaque connexion. Cet
identifiant sera le seul identifiant de présence exposé au client ; aucun nom de joueur ne sera
géré par GWRank.

### Snapshot et coordination

Chaque salon sera stocké sous une clé de cache versionnée, avec un index séparé pour la capacité :

- `gwrank:rooms:v1:<code>` contient le digest créateur, les échéances, les connexions, les leases de présence, la version et le dernier paquet base64.
- `gwrank:rooms:v1:index` contient les codes et leurs échéances approximatives.

`Rooms::SessionStore` sera la seule abstraction autorisée à lire ou modifier ces valeurs. Les
transitions seront protégées par `pg_advisory_xact_lock` sur le code du salon ; la création et le
nettoyage de l'index utiliseront une clé de verrou globale distincte. Le cache reste la source de
vérité éphémère ; aucun modèle, migration ou table métier de salon ne sera ajouté.

Les écritures du dernier paquet sont last-write-wins au niveau du serveur. Une version monotone
attribuée sous verrou accompagne chaque paquet afin que le client puisse ignorer un événement
arrivé hors ordre. Cette version ne fusionne pas les modifications et ne remplace pas les verrous
par personnage de Z-Codex.

## Protocole

### Paquets client

Le client envoie une action Action Cable `receive` contenant une charge base64 :

```json
{
  "action": "receive",
  "payload": "BASE64"
}
```

Le serveur vérifie que l'enveloppe est JSON, que `payload` est une chaîne base64 stricte et que la
charge décodée ne dépasse pas 16 KiB. Il ne parse pas les octets décodés et ne les journalise pas.

### Messages serveur

Le nouvel arrivant reçoit directement :

```json
{
  "type": "room.ready",
  "connectionId": "uuid",
  "participants": ["uuid"],
  "state": {
    "version": 12,
    "payload": "BASE64"
  },
  "expiresAt": "2026-09-23T18:00:00Z"
}
```

Quand aucun paquet n'a encore été reçu, `state` vaut `null`. Les autres participants reçoivent :

```json
{"type":"room.joined","connectionId":"uuid"}
{"type":"room.left","connectionId":"uuid"}
{"type":"state.updated","senderId":"uuid","version":13,"payload":"BASE64"}
```

L'émetteur ne reçoit pas son propre `state.updated`. Le paquet est toutefois enregistré avant la
diffusion afin qu'une reconnexion le retrouve.

Une expiration diffuse avant fermeture :

```json
{"type":"room.expired","reason":"creator_timeout"}
```

Les valeurs de `reason` sont `creator_timeout` et `max_lifetime`.

## Cycle de vie

### Souscription

La souscription verrouille le salon, vérifie son existence et son échéance, valide le secret si le
champ est présent, purge les leases mortes et vérifie la limite de huit participants. Elle ajoute
ensuite la connexion, transmet `room.ready`, puis diffuse `room.joined` aux connexions existantes.

Une connexion authentifiée par le secret créateur devient la connexion créateur. Si elle remplace
une ancienne connexion créateur encore visible, l'ancienne est invalidée et ne pourra pas déclencher
la grace lors de son départ tardif : son `connectionId` ne correspondra plus à celui enregistré.

### Présence et reconnexion

Chaque `RoomChannel` exécutera un timer Action Cable toutes les 30 secondes pour renouveler son
lease. Un timer qui observe un salon expiré déclenche la fermeture pour tous les abonnés. Une
connexion sans lease depuis 90 secondes est retirée et génère `room.left`, ce qui couvre aussi la
perte brutale d'un processus sans callback `unsubscribed`.

Le keepalive de transport Action Cable reste celui fourni par Rails. Le délai 30/90 secondes est
le contrat de présence de la session, pas une modification du heartbeat interne Action Cable.

Après une coupure, le code reste valable jusqu'à l'expiration du salon et une nouvelle souscription
reçoit un nouvel `connectionId`, la liste courante et le dernier état. Le `creatorSecret` reste
valable pendant la grace de cinq minutes.

### Expiration

À la déconnexion ou à la perte de lease du créateur, le snapshot enregistre `creatorGraceUntil =
now + 5 minutes`. Les autres participants peuvent continuer à travailler pendant cette grace et
le créateur peut reprendre son rôle avec son secret. À défaut de reconnexion, le salon est expiré,
son snapshot et son entrée d'index sont supprimés, puis les connexions reçoivent `room.expired` et
sont fermées.

L'échéance absolue de deux heures est prioritaire sur la grace. Aucun timer persistant n'est
nécessaire : les connexions actives exécutent le contrôle périodique ; un salon sans connexion n'a
aucune connexion à fermer et son cache expire naturellement.

## Gestion des erreurs

Les codes de fermeture sont :

| Code | Motif | Reconnexion automatique |
|---|---|---|
| `1000` | fermeture normale | non nécessaire |
| `1008` | enveloppe ou protocole invalide | non |
| `1009` | charge décodée supérieure à 16 KiB | non |
| `1013` | indisponibilité technique temporaire | oui, avec backoff |
| `4401` | secret créateur invalide | non |
| `4404` | salon inconnu, expiré ou supprimé | non |
| `4409` | salon complet | après action utilisateur |
| `4429` | débit supérieur à 10 messages/seconde | après backoff |

Les codes `4401`, `4404`, `4409` et `4429` auront un motif court sans donnée sensible. Une
fermeture permanente enverra aussi le signal Action Cable `reconnect: false`; `1013` conservera la
possibilité de reconnexion.

L'API de fermeture publique Action Cable ne permet pas de choisir le code WebSocket. Un adaptateur
isolé dans `ApplicationCable::Connection` appellera l'interface bas niveau de la version Rails
installée après avoir envoyé le signal Action Cable approprié. Cette dépendance interne sera
couverte par un test ciblé afin qu'une mise à jour Rails la rende immédiatement visible.

## Composants et fichiers

- `config/routes.rb` : route REST et montage Action Cable.
- `app/controllers/api/v1/rooms_controller.rb` : authentification Bearer et création.
- `app/channels/application_cable/connection.rb` : `connectionId` et fermeture codée.
- `app/channels/room_channel.rb` : souscription, réception, diffusion, présence et expiration.
- `app/services/rooms/session_store.rb` : cache, locks, index, limites et transitions.
- Composant de protocole sous `app/services/rooms/` : base64, tailles, enveloppes et codes d'erreur.
- Tests Minitest sous `test/controllers/api/v1/`, `test/channels/` et `test/services/rooms/`.
- `config/initializers/filter_parameter_logging.rb` : garantir que secrets et charges ne sont jamais journalisés.

Aucune migration, aucun modèle Active Record de salon et aucune dépendance externe nouvelle ne
seront ajoutés.

## Stockage et confidentialité

Le cache de production actuel est Solid Cache, partagé entre les processus web. Le cache de
développement est actuellement local au processus ; les tests du store injecteront un cache
partagé simulé ou Solid Cache pour couvrir la sémantique multi-processus.

Solid Cable utilise actuellement `solid_cable_messages` comme file de transport temporaire avec la
rétention configurée. Les broadcasts de salon peuvent donc exister en base pendant cette rétention comme
messages de transport, mais ils ne sont jamais relus comme historique et aucun stockage métier de
session n'est créé. Cette approche ne prétend pas garantir qu'aucun octet de payload ne touche une
base ; cette exigence stricte nécessiterait un transport pub/sub non persistant, tel que Redis.

Le serveur ne connaît pas le format `.zcx`. Si Z-Codex chiffre les charges côté client, la même
enveloppe et les mêmes limites restent valables.

## Vérification

Les tests devront prouver :

- la création avec et sans Bearer token, la réponse `201` et la capacité globale ;
- la génération, le digest et la validation du secret créateur ;
- l'accès code seul, le rejet d'un code inconnu et le rejet d'un secret invalide ;
- l'admission à huit participants et le rejet `4409` du neuvième ;
- la transmission du snapshot au nouvel arrivant ;
- la diffusion aux autres participants sans diffusion au sender ;
- la base64 invalide, la limite de 16 KiB et le débit de 10 messages/seconde ;
- les événements de présence, les leases mortes et les départs idempotents ;
- la reconnexion créateur pendant la grace et l'expiration après cinq minutes ;
- l'expiration absolue à deux heures et les codes de fermeture ;
- les courses concurrentes de création, admission et remplacement du snapshot sous locks.

La vérification finale utilisera les tests ciblés Minitest, la suite Rails pertinente, une preuve
HTTP réelle de `POST /api/v1/rooms` et un test Action Cable avec au moins deux abonnés.

## Hors périmètre

- lecture ou validation du format `.zcx` ;
- résolution de conflit ou verrouillage de personnages côté serveur ;
- persistance de builds, chat, historique, rôles ou propriété ;
- modération ;
- reconnexion ou regroupement des rafales côté serveur ;
- chiffrement applicatif des paquets ;
- interface utilisateur GWRank pour créer ou rejoindre un salon.
