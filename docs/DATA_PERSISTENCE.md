# GRAB & GROW — Persistance des profils joueurs

Dernière mise à jour : 2026-11-11 (T1)

Références : architecture technique section 7 ; décisions D-006, D-008,
D-009. Réglages : `Shared/Config/DataConfig.lua`.

## Modules

| Module | Rôle |
|---|---|
| `Shared/Config/DataConfig.lua` | Version du schéma, noms de DataStore, reprises, verrou, sauvegarde auto |
| `Systems/DataSchema.lua` | Profil par défaut, contrôle d'intégrité, migrations (logique pure) |
| `Services/PlayerDataService.lua` | Chargement, données en mémoire, sauvegarde, verrou de session |
| `Systems/MemoryDataStore.lua` | Magasin en mémoire (tests, Studio) |
| `Systems/PlayerSession.lua` | Branchement Roblox : PlayerAdded, PlayerRemoving, sauvegarde auto, BindToClose |
| `Bootstrap.server.lua` | Choix du magasin, création du service |

## Stockage

- DataStore : `GrabAndGrow_PlayerData_v1` (production).
- Clé : `Player_<UserId>`.
- Valeur : `{ profile = <profil v1>, session = { id, expiresAt } | nil }`.
- Toute lecture et écriture passe par `UpdateAsync` (opération atomique).
- `UserId` associé à la clé (paramètre `userIds`), pour les demandes
  d'effacement.

## API de `PlayerDataService`

Le service est créé par `PlayerDataService.new(dépendances)` et identifie
les joueurs par `UserId`. Chaque fonction retourne
`{ ok, code?, message? }`, sauf `IsLoaded` et `GetData`.

| Fonction | Effet |
|---|---|
| `LoadPlayer(userId)` | Prend le verrou et charge le profil. Bloquant. |
| `IsLoaded(userId)` | `true` seulement si le profil est utilisable. |
| `GetData(userId)` | **Copie** du profil, ou `nil`. Modifier la copie est sans effet. |
| `Update(userId, mutator)` | Seule voie de modification (voir ci-dessous). |
| `SavePlayer(userId)` | Écrit le profil et renouvelle le verrou. |
| `ReleasePlayer(userId)` | Sauvegarde finale, libère le verrou, vide la mémoire. |
| `Shutdown()` | Libère tous les profils, refuse tout nouveau chargement. |

### Modifier un profil (futurs services)

```lua
local result = playerData.Update(userId, function(draft)
    if draft.currencies.coins < cost then
        return false -- abandon : rien ne change
    end
    draft.currencies.coins -= cost
    draft.upgrades.backpackLevel += 1
end)
```

- `mutator` reçoit un brouillon (copie). Le brouillon ne remplace le
  profil que s'il respecte le schéma, sans aucune réparation : tout ou rien.
- Une erreur, un retour `false`, une valeur invalide ou une suspension du
  fil (`task.wait`, appel réseau) annulent la modification.
- `Update` ne déclenche aucune écriture DataStore.
- Coût : une copie et un contrôle du profil par appel. À mesurer en T6.

## Chargement

1. `UpdateAsync` lit la valeur et, dans la même opération, pose le verrou.
2. Clé absente (lue sans erreur) : profil par défaut créé.
3. Valeur présente : migration vers la version courante, puis contrôle.
4. Erreur DataStore : jusqu'à 5 tentatives, attentes de 1, 2, 4, 8 s.
5. Échec définitif, données refusées ou verrou actif : rien n'est écrit,
   aucun profil n'existe en mémoire, le joueur est expulsé avec un message.
   Un échec n'est jamais traité comme un nouveau joueur.

### Intégrité (D-008)

| Constat au chargement | Traitement |
|---|---|
| Champ ou section manquant | Valeur par défaut ajoutée, journalisée |
| Niveau hors bornes, solde négatif, décimale | Borné ou arrondi, journalisé |
| Monde de départ verrouillé | Débloqué, journalisé |
| Clé inconnue (y compris ressource absente de `ResourceConfig`) | Conservée |
| Type incorrect, NaN, section non table, verrou illisible | **Refus** `CorruptData` |
| `schemaVersion` supérieur à celui du serveur | **Refus** `UnsupportedVersion` |
| Migration absente ou en erreur | **Refus** `MigrationFailed` |

Un profil refusé reste intact dans le DataStore : correction manuelle
nécessaire. Bornes des niveaux : `UpgradeConfig` pour Backpack et Grabber,
`DataConfig.NonMvpUpgradeMaxLevels` pour Magnet, Boots et Multiplier.

## Sauvegarde

- Périodique : toutes les 60 s par joueur chargé. Écrit toujours, car
  l'écriture renouvelle le verrou.
- À la sortie du joueur (`ReleasePlayer`) et à l'arrêt du serveur
  (`BindToClose` → `Shutdown`, profils traités en parallèle).
- Jamais à chaque modification.
- Une seule écriture à la fois par profil. Une demande reçue pendant une
  écriture provoque une seconde écriture à la suite, qui contient les
  modifications faites entre-temps.
- Échec après toutes les reprises : les données restent en mémoire, la
  sauvegarde suivante réessaie.
- `lastSaveAt` (heure Unix) est fixé à chaque écriture.

## Verrou de session

- Identifiant : `<JobId>:<numéro de chargement>`, unique par chargement.
- Validité : 180 s après la dernière écriture ; renouvelé à chaque
  sauvegarde (60 s).
- Verrou actif d'une autre session : le chargement attend (6 tentatives
  espacées de 5 s), puis refuse `SessionLocked`. Le verrou n'est jamais
  remplacé tant qu'il est valide.
- Verrou expiré : le nouveau serveur le reprend et lit la dernière
  sauvegarde.
- Chaque écriture vérifie que le verrou stocké est le sien. Sinon : aucune
  écriture, code `LockLost`, profil retiré de l'usage, joueur expulsé.
- La libération retire le verrou dans la même écriture que la sauvegarde
  finale. Une session ne peut pas retirer le verrou d'une autre.

## Migrations

`DataSchema.Migrations[n]` transforme un profil de version `n` en version
`n + 1` et fixe son `schemaVersion`. Table vide en v1. Pour passer en v2 :

1. Augmenter `DataConfig.SchemaVersion`.
2. Ajouter `Migrations[1]`.
3. Mettre à jour `newProfile` et le contrôle dans `DataSchema`.
4. Ajouter des tests sur des profils v1 représentatifs.
5. Noter le changement ici.

Attention : après publication d'une v2, un retour à un serveur v1 refuse
les profils déjà migrés (`UnsupportedVersion`). Prévoir le retour arrière
avant toute hausse de version.

## Environnements

| Contexte | Magasin |
|---|---|
| Serveur publié | DataStore `GrabAndGrow_PlayerData_v1` |
| Studio, `DataConfig.Studio.useMemoryStore = true` (défaut) | Mémoire, perdu à l'arrêt |
| Studio, `useMemoryStore = false` | DataStore `GrabAndGrow_PlayerData_v1_Studio` |
| Tests automatisés | `MemoryDataStore` injecté |

Le magasin en mémoire exige `RunService:IsStudio()` **et** le réglage :
il ne peut pas s'activer sur un serveur publié. Studio n'écrit jamais dans
le DataStore de production.

## Limites connues

- **Crash serveur ou coupure brutale** : les modifications depuis la
  dernière sauvegarde réussie sont perdues (jusqu'à 60 s, davantage si les
  sauvegardes échouaient). Le verrou reste posé : le joueur ne peut pas
  recharger son profil avant son expiration (jusqu'à 180 s).
- **Arrêt du serveur** : Roblox accorde environ 30 s à `BindToClose`. Un
  DataStore très lent peut empêcher certaines sauvegardes finales.
- **Sauvegarde de sortie en échec** : la progression depuis la dernière
  sauvegarde réussie est perdue, le verrou expire seul.
- **Serveur figé plus de 180 s puis réveillé** : un autre serveur a pu
  reprendre le profil ; la session figée perd ses modifications non
  sauvegardées (elle ne peut plus écrire).
- **Horloges** : l'expiration compare `os.time()` de serveurs différents ;
  un écart de quelques secondes est sans effet face aux 180 s.
- **Panne DataStore prolongée** : les joueurs sont refusés à l'entrée.
- **Profil corrompu** : le joueur est bloqué jusqu'à correction manuelle.
- **Quotas** : une écriture par joueur et par minute, plus chargement et
  sortie. Non mesuré sur un serveur réel.
- **Messages d'expulsion** : texte anglais brut, non localisé.
- **`stats.playTimeSeconds`** : présent dans le schéma, alimenté par aucun
  système pour l'instant.
- **Magasin en mémoire** : ne reproduit ni quotas, ni latence, ni limite
  de taille du DataStore réel.

## État de validation

| Élément | Magasin en mémoire (Lune, Studio) | DataStore réel |
|---|---|---|
| Chargement, nouveau profil | Validé | **Non vérifié** |
| Sauvegarde automatique 60 s | Validé par simulation | **Non vérifié** |
| Sauvegarde de sortie, `BindToClose` | Validé par simulation ; Studio sans erreur | **Non vérifié** |
| Verrou, deux serveurs, expiration | Validé par simulation | **Non vérifié** |

Suivi détaillé : `PROJECT_STATUS.md`, V-01 à V-05.

## Vérification avec le DataStore réel (manuelle, non faite)

À réaliser sur un place de test publié, jamais sur la production :

1. Publier le place sur une expérience de test.
2. Studio : Game Settings > Security > Enable Studio Access to API Services.
3. `DataConfig.Studio.useMemoryStore = false`.
4. Play : vérifier `[Bootstrap] DataStore : GrabAndGrow_PlayerData_v1_Studio`
   puis `nouveau profil créé`.
5. Stop, puis Play : vérifier `profil chargé`.
6. Remettre `useMemoryStore = true`.
